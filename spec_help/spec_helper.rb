require 'rspec'
require 'file-sandbox'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir     = 'spec_help/cassettes'
  c.hook_into                :excon
  c.default_cassette_options = { :record => :once }
end

RSpec.configure do |config|
  config.extend VCR::RSpec::Macros
end

require 'our-eel-hacks/heroku-client'
class OurEelHacks::HerokuClient
  alias real_ps ps
  alias real_ps_scale ps_scale

  class << self
    attr_accessor :processing_budget
  end

  def ps(*args, &block)
    #puts caller.grep %r{#{File::expand_path("../..",__FILE__)}}
    if (self.class.processing_budget -= 1) < 0
      raise "Exhausted processing budget"
    end
    real_ps(*args, &block)
  end

  def ps_scale(*args, &block)
    #puts caller.grep %r{#{File::expand_path("../..",__FILE__)}}
    if (self.class.processing_budget -= 1) < 0
      raise "Exhausted processing budget"
    end
    real_ps_scale(*args, &block)
  end
end

$" << "eventmachine"

module EventMachine
  def self.defer
    yield
  end

  def self.reactor_running?
    true
  end
end

EM = EventMachine
