require "yaml"

class Config
  attr_reader :config

  DEFAULT_CONFIG = {
    input_dir: "/input",
    output_dir: "/output",
    transcode: %w[mkv mp4 avi mpeg wmv],
    passthrough: %w[srt sub idx jpg jpeg png],
    log_level: :warn,
    ffmpeg_logs: false,
    allow_overwrite: false,
    enqueue_on_start: true,
  }.freeze

  def self.load_config
    file = ARGV[0] || "config.yml"
    if File.exist?(file)
      DEFAULT_CONFIG.merge(YAML.load_file(file).transform_keys(&:to_sym))
    else
      DEFAULT_CONFIG
    end
  end

  def self.method_missing(m, *_args)
    @config ||= load_config
    @config[m]
  end

  def self.respond_to_missing?
    true
  end
end