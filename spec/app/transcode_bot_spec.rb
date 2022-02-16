require "digest"
require "open3"
require "securerandom"

require "spec_helper"

# NB: these are accpetance tests that actually run the bot in one shot mode. much more telling than unit tests imo.

def create_test_h264(filename = "#{SecureRandom.uuid}.mp4", length = 1)
  Open3.capture2("ffmpeg -f lavfi -i testsrc=duration=#{length}:size=1280x720:rate=30 -vcodec libx264 -acodec aac /tmp/input/#{filename}")
  filename
end

def create_test_h265(filename = "#{SecureRandom.uuid}.mp4", length = 1)
  Open3.capture2e("ffmpeg -f lavfi -i testsrc=duration=#{length}:size=1280x720:rate=30 -vcodec libx265 -acodec aac /tmp/input/#{filename}")
  filename
end

def create_config(options, filename = "/tmp/config.yml")
  File.write(filename, options.to_yaml)
  filename
end

describe "TranscodeBot" do
  before(:all) do
    Open3.capture2("mkdir -p /tmp/input")
    Open3.capture2("mkdir -p /tmp/output")
  end

  before(:each) do
    create_config({input_dir: "/tmp/input", output_dir: "/tmp/output", one_shot: true, log_level: "info"})
    `rm -rf /tmp/input/*`
    `rm -rf /tmp/output/*`
  end

  it "takes files from the input and puts them in the output" do
    files = [create_test_h264, create_test_h264]

    # run the bot
    Open3.capture2e("ruby app/transcode_bot.rb /tmp/config.yml")

    # check the output
    File.exist?("/tmp/output/#{files.first.gsub('mp4', 'mkv')}").should be true
    File.exist?("/tmp/output/#{files.last.gsub('mp4', 'mkv')}").should be true
  end

  it "passes through files already encoded in HEVC" do
    file = create_test_h265

    # run the bot
    Open3.capture2e("ruby app/transcode_bot.rb /tmp/config.yml")

    # check the output
    File.exist?("/tmp/output/#{file.gsub('mp4', 'mkv')}").should be false
    File.exist?("/tmp/output/#{file}").should be true
    Digest::SHA1.file("/tmp/output/#{file}").should == Digest::SHA1.file("/tmp/input/#{file}")
  end

  it "passes through files in the whitelist" do
    File.write("/tmp/input/test.srt", "test")

    # run the bot
    Open3.capture2e("ruby app/transcode_bot.rb /tmp/config.yml")

    # check the output
    File.exist?("/tmp/output/test.srt").should be true
    Digest::SHA1.file("/tmp/output/test.srt").should == Digest::SHA1.file("/tmp/input/test.srt")
  end

  it "ignores unprocessable files" do
    File.write("/tmp/input/test.txt", "test")

    # run the bot
    Open3.capture2e("ruby app/transcode_bot.rb /tmp/config.yml")

    # check the output
    File.exist?("/tmp/output/test.txt").should be false
  end
end
