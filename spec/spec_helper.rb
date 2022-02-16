$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, "../")))
$LOAD_PATH.unshift(File.expand_path(__dir__))

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = %i[should expect]
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = %i[should expect]
  end
end
