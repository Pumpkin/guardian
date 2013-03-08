require 'English'
$LOAD_PATH.unshift File.expand_path('lib/guardian', File.expand_path('../..', __FILE__))

RSpec.configure do |config|
  config.filter_run :focused => true
  config.run_all_when_everything_filtered = true
  config.alias_example_to :fit, :focused => true
end
