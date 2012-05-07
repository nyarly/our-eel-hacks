require 'spec_helper'
require 'our-eel-hacks/sidekiq'

class Sidekiq;
  def self.redis
    100
  end
end

describe OurEelHacks::Sidekiq do
  use_vcr_cassette :record => :once

  let :app_name do
    "sbmp"
  end

  let :api_key do
    "FakeApiKey"
  end

  before :each do
    OurEelHacks::Autoscaler.configure(:test) do |test|
      test.app_name = app_name
      test.heroku_api_key = api_key
      test.ps_type = "web"
    end
  end

  before :each do
    future = Celluloid::Future
    def future.new
      yield
    end
  end

  let :middleware do
    OurEelHacks::Sidekiq.new(:test)
  end

  it "should pass the metric to the autoscaler" do
    OurEelHacks::Autoscaler.instance_for(:test).should_receive(:scale).with(100)
    middleware.call(String, {}, :default) do
    end
  end
end
