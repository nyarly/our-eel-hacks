require 'our-eel-hacks/rack'

describe OurEelHacks::Rack do
  use_vcr_cassette :record => :once

  let :app_name do
    "sbmp"
  end

  let :api_key do
    "FakeApiKey"
  end

  before :each do
    OurEelHacks::HerokuClient.processing_budget = 3
    OurEelHacks::Autoscaler.configure(:test) do |test|
      test.app_name = app_name
      test.heroku_api_key = api_key
      test.ps_type = "web"
    end
  end

  let :fake_app do
    mock("Rack App").tap do |app|
      app.stub!(:call)
    end
  end

  let :env_field do
    "HTTP_X_HEROKU_QUEUE_DEPTH"
  end

  let :middleware do
    OurEelHacks::Rack.new(fake_app, env_field, :test)
  end


  it "should pass the metric to the autoscaler" do
    OurEelHacks::Autoscaler.instance_for(:test).should_receive(:scale).with({env_field => 100})
    middleware.call({env_field => "100"})
  end
end
