require "spec_helper"
require "app/config"

describe Config do
  before :each do
    Config.instance_variable_set(:@config, nil)
  end

  it "loads the config given as an argument" do
    ARGV.replace(["test.yml"])
    File.should_receive(:exist?).with("test.yml").and_return(false)
    Config.load_config
  end

  it "uses defaults" do
    File.should_receive(:exist?).and_return(false)
    Config.load_config.should == Config.const_get(:DEFAULT_CONFIG)
  end

  it "loads the config from a file and overrides defaults" do
    File.stub(:exist?).and_return(true)
    YAML.stub(:load_file).and_return({"input_dir" => "/new_input"})
    Config.input_dir.should == "/new_input"
    Config.output_dir.should == "/output"
  end

  it "loads arbitrary config values" do
    File.stub(:exist?).and_return(true)
    YAML.stub(:load_file).and_return({"lemon" => "hello"})
    Config.lemon.should == "hello"
  end
end
