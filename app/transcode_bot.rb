require "logger"
require "open3"
require "pathname"
require "fileutils"

require "./app/config"

$stdout.sync = true

$logger = Logger.new $stdout
$logger.level = Config.log_level
$queue = []

$logger.error "TranscodeBot started"

def can_transcode?(file)
  Config.transcode.include? file.extname.downcase.delete_prefix(".")
end

def correct_permissions(file)
  if Config.fmode && Config.uid && Config.gid
    $logger.info "correcting permissions on #{file}"
    File.chmod(Config.fmode.to_i(8), file.to_s) if Config.fmode
    File.chown(Config.uid.to_i, Config.gid.to_i, file.to_s) if Config.uid && Config.gid
  else
    $logger.info "not correcting permissions on #{file} - FMODE, UID, or GID missing."
  end
end

def hevc?(file)
  output, status = Open3.capture2e("ffprobe -i \"#{file}\"")
  return false unless status.exitstatus.zero?
  output.upcase.include? "HEVC"
end

def whitelisted?(file)
  Config.passthrough.include? file.extname.downcase.delete_prefix(".")
end

def mkdirs(file)
  FileUtils.mkdir_p(file.parent)
  correct_permissions(file.parent)
end

def move(from, to)
  File.delete from if Config.allow_overwrite
  mkdirs Pathname.new(to)
  FileUtils.copy from, to
end

def should_passthrough?(file)
  whitelisted?(file) || hevc?(file)
end

def transcode(input, output)
  command = Config.force_cmd.dup
  command ||= "ffmpeg -y -i \"$input\" -map 0:v:0 -map 0:a? -map 0:s? -max_muxing_queue_size 9999 -c:v libx265 -preset fast -x265-params crf=22:qcomp=0.8:aq-mode=1:aq_strength=1.0:qg-size=16:psy-rd=0.7:psy-rdoq=5.0:rdoq-level=1:merange=44 -c:a copy -c:s copy \"$output\""
  command.gsub! "$input", input.to_s
  command.gsub! "$output", output.to_s
  _out, error, status = Open3.capture3(command)
  unless status.exitstatus.zero?
    $logger.error "Error processing #{input}:"
    $logger.error error
    return false
  end
  true
end

def process_file(input_filename)
  # calculate filenames
  input_file = Pathname.new(input_filename)
  relative = Pathname.new(input_file).relative_path_from Pathname.new(Config.input_dir)
  ext = input_file.extname
  new_ext = whitelisted?(input_file) ? ext : ".mkv"
  intermediate_file = Pathname.new("/tmp/#{relative.to_s.gsub(ext, new_ext)}")
  output_file = Pathname.new("#{Config.output_dir}/#{relative.to_s.gsub(ext, new_ext)}")

  $logger.info "working on #{input_file} -> #{output_file}"
  mkdirs intermediate_file

  unless input_file.exist?
    $logger.info "input #{input_file} no longer exists. skipping."
    return
  end

  if output_file.exist? && !Config.allow_overwrite
    $logger.info "output #{output_file} already exists. skipping"
    return
  end

  # bypass if it's whitelisted or already hevc
  if should_passthrough? input_file
    $logger.info "passing through #{input_file}"
    output_file = Pathname.new("#{Config.output_dir}/#{relative}")
    move input_file, output_file
    correct_permissions output_file
  elsif can_transcode? input_file
    # we should transcode it
    start_time = Time.now
    $logger.info "transcoding #{input_file}"
    if transcode(input_file, intermediate_file)
      move intermediate_file, output_file
      correct_permissions output_file
      intermediate_file.delete
      $logger.info "transcoding done, took #{Time.now - start_time} seconds, #{$queue.size} items remaining"
    else
      $logger.error "transcode failed, took #{Time.now - start_time} seconds, #{$queue.size} items remaining"
    end
  else
    $logger.info "not passing through and not on the list of transcodable media. skipping."
    return
  end

  $logger.info "finished with #{input_file}"
end

def enqueue_file(file)
  $logger.info "enqueuing #{file}"
  $queue << file
end

Dir["#{Config.input_dir}/**/*"].reject { |fn| File.directory?(fn) }.each { |fn| enqueue_file(fn) } if Config.enqueue_on_start || Config.one_shot

unless Config.one_shot
  require "rb-inotify"

  notifier = INotify::Notifier.new
  notifier.watch(Config.input_dir, :close_write, :moved_to, :recursive) do |event|
    if File.file?(event.absolute_name)
      $logger.info("file created: #{event.absolute_name}")
      enqueue_file(event.absolute_name)
    end
  end

  notifier.run
end

worker = Thread.new do
  loop do
    file = $queue.shift
    process_file(file) if file
    break if file.nil? && Config.one_shot
    sleep 1 unless file
  end
end

worker.join

$logger.error "Transcode Bot Exiting"
