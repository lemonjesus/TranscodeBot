require "logger"
require "open3"
require "rb-inotify"
require "pathname"
require "fileutils"

STDOUT.sync = true

$logger = Logger.new STDOUT
$input_dir = ENV["INPUT_DIR"] || "/input"
$output_dir = ENV["OUTPUT_DIR"] || "/output"
$queue = []

$logger.info "TranscodeBot started"

def can_transcode?(file)
  %w[.mkv .mp4 .avi .mpeg .wmv].include? file.extname.downcase
end

def correct_permissions(file)
  $logger.info "correcting permissions on #{file.to_s}"
  File.chmod(ENV["FMODE"].to_i(8), file.to_s) if ENV["FMODE"]
  File.chown(ENV["UID"].to_i, ENV["GID"].to_i, file.to_s) if ENV["UID"] && ENV["GID"]
end

def is_hevc?(file)
  output, status = Open3.capture2e("ffprobe -i \"#{file.to_s}\"")
  return false unless status == 0
  output.upcase.include? "HEVC"
end

def is_whitelisted?(file)
  %w[.srt .idx .jpg .jpeg .png].include? file.extname.downcase
end

def mkdirs(file)
  FileUtils.mkdir_p(file.parent, mode: ENV["FMODE"].to_i(8))
  correct_permissions(file.parent)
end

def move(from, to)
  File.delete from if ENV["ALLOW_OVERWRITE"]
  mkdirs Pathname.new(to)
  FileUtils.copy from, to
end

def should_passthrough?(file)
  is_whitelisted?(file) || is_hevc?(file)
end

def transcode(input, output)
  command = ENV["FORCE_CMD"]
  command ||= "ffmpeg -y -i \"$input\" -map 0:v -map 0:a -max_muxing_queue_size 9999 -c:v libx265 -preset fast -x265-params crf=22:qcomp=0.8:aq-mode=1:aq_strength=1.0:qg-size=16:psy-rd=0.7:psy-rdoq=5.0:rdoq-level=1:merange=44 -c:a copy -c:s copy \"$output\""
  command.gsub! "$input", input.to_s
  command.gsub! "$output", output.to_s
  out, error, status = Open3.capture3(command)
  unless status == 0
    $logger.error "Error processing #{input.to_s}:"
    $logger.error error
    return false
  end
  true
end

def process_file(input_filename)
  # calculate filenames
  input_file = Pathname.new(input_filename)
  relative = Pathname.new(input_file).relative_path_from Pathname.new($input_dir)
  ext = input_file.extname
  new_ext = is_whitelisted?(input_file) : ".mkv" : ext
  intermediate_file = Pathname.new("/tmp/#{relative.to_s.gsub(ext, new_ext)}")
  output_file = Pathname.new("#{$output_dir}/#{relative.to_s.gsub(ext, new_ext)}")

  $logger.info "working on #{input_file} -> #{output_file}"
  mkdirs intermediate_file

  if output_file.exist? && !ENV["ALLOW_OVERWRITE"]
    $logger.info "output #{output_file} already exists. skipping"
    return
  end

  # bypass if it's whitelisted or already hevc
  if should_passthrough? input_file
    $logger.info "passing through #{input_file}"
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
      # input_file.delete if ENV["DELETE_SOURCE"]
      $logger.info "transcoding done, took #{Time.now - start_time} seconds"
    else
      $logger.error "transcode failed, took #{Time.now - start_time} seconds"
    end
  else
    $logger.info "not passing through and not on the list of transcodable media. skipping."
    return
  end

  $logger.info "finished with #{input_file}"
end

def enqueue_file(file)
  $queue << file
end

worker = Thread.new do
  loop do
    file = $queue.pop
    process_file(file) if file
    sleep 1 unless file
  end
end

Dir['**/*'].reject {|fn| File.directory?(fn) }.each { |fn| enqueue_file(fn) } if ENV["ENQUEUE_ON_START"]

notifier = INotify::Notifier.new
notifier.watch($input_dir, :close_write, :moved_to, :recursive) do |event|
  if File.file?(event.absolute_name)
    $logger.info("file created: #{event.absolute_name}")
    enqueue_file(event.absolute_name)
  end
end

notifier.run

$logger.error "Transcode Bot Exiting"
