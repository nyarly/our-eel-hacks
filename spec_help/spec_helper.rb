require 'rspec'
require 'file-sandbox'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir     = 'spec_help/cassettes'
  c.hook_into                :fakeweb
  c.default_cassette_options = { :record => :new_episodes }
end

RSpec.configure do |config|
  config.extend VCR::RSpec::Macros
end
