require 'rspec'
require 'file-sandbox'
require 'vcr'

VCR.config do |c|
  c.cassette_library_dir     = 'spec_help/cassettes'
  c.stub_with                :fakeweb
  c.default_cassette_options = { :record => :new_episodes }
end

RSpec.configure do |config|
  config.extend VCR::RSpec::Macros
end
