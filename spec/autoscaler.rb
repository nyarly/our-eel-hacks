require 'spec_helper'
require 'our-eel-hacks/rack'
require 'logger'

describe OurEelHacks::Autoscaler do
  before :each do
    FakeWeb.allow_net_connect = false
  end

  use_vcr_cassette :record => :once

  let :app_name do
    "sbmp"
  end

  let :api_key do
    "FakeApiKey"
  end

  let :scaling_freq do
    200
  end

  let :soft_dur do
    500
  end

  let :ideal_value do
    25
  end

  let :soft_high do
    35
  end

  let :soft_low do
    3
  end

  let :hard_high do
    100
  end

  let :hard_low do
    -10
  end

  let! :starting_time do
    Time.now
  end

  def time_adjust(millis)
    Time.stub!(:now).and_return(Time.at(starting_time, millis))
  end

  let :logger do
    Logger.new($stdout).tap{|lgr| lgr.level = Logger::INFO }
  end

  let :autoscaler do
    time_adjust(0)
    OurEelHacks::Autoscaler.new.tap do |test|
      test.configure do |test|
        test.app_name = app_name
        test.heroku_api_key = api_key
        test.ps_type = "web"
        test.scaling_frequency = scaling_freq
        test.soft_duration = soft_dur

        test.lower_limits.hard = 1
        test.lower_limits.soft = 5

        test.upper_limits.soft = 30
        test.upper_limits.hard = 50

        #test.logger = logger
      end
    end
  end

  let :heroku do
    autoscaler.heroku
  end

  it "should get a count of dynos at start" do
    autoscaler.dynos.should == 3 #happens to be the number of web dynos right now
  end

  before :each do
    heroku.stub!(:ps_scale)
    time_adjust(0)
    autoscaler.scale(ideal_value)
  end

  describe "scaling frequency" do

    it "should not scale too soon" do
      time_adjust(scaling_freq - 5)

      heroku.should_not_receive(:ps_scale)
      autoscaler.scale(hard_high)
    end

    it "should scale up if time has elapsed and hard limit exceeded" do
      time_adjust(scaling_freq + 5)

      heroku.should_receive(:ps_scale).with(app_name, hash_including(:qty => 4))
      autoscaler.scale(hard_high)
    end
  end

  describe "hard limits" do
    before :each do
      time_adjust(scaling_freq + 5)
    end

    it "should scale down if hard lower limit exceeded" do
      heroku.should_receive(:ps_scale).with(app_name, hash_including(:qty => 2))
      autoscaler.scale(hard_low)
    end
  end

  describe "soft upper limit" do
    before :each do
      time_adjust(scaling_freq * 2)
      autoscaler.scale(soft_high)
    end

    describe "if soft_duration hasn't elapsed" do
      before :each do
        time_adjust((scaling_freq * 2) + soft_dur - 5)
        heroku.should_not_receive(:ps_scale)
      end

      it "should not scale up" do
        autoscaler.scale(soft_high)
      end

      it "should not scale down" do
        autoscaler.scale(soft_low)
      end
    end

    describe "if soft_duration has elapsed" do
      before :each do
        time_adjust(scaling_freq * 2 + soft_dur + 5)
      end

      it "should scale up if above upper soft limit" do
        heroku.should_receive(:ps_scale).with(app_name, hash_including(:qty => 4))
        autoscaler.scale(soft_high)
      end

      it "should not scale down if below lower soft limit" do
        heroku.should_not_receive(:ps_scale)
        autoscaler.scale(soft_low)
      end
    end
  end

  describe "soft lower limit" do
    before :each do
      time_adjust(scaling_freq * 2)
      autoscaler.scale(soft_low)
    end

    describe "if soft_duration hasn't elapsed" do
      before :each do
        time_adjust(scaling_freq * 2 + soft_dur - 5)
        heroku.should_not_receive(:ps_scale)
      end

      it "should not scale up" do
        autoscaler.scale(soft_high)
      end

      it "should not scale down" do
        autoscaler.scale(soft_low)
      end
    end

    describe "if soft_duration has elapsed" do
      before :each do
        time_adjust(scaling_freq * 2 + soft_dur + 5)
      end

      it "should not scale up even if above upper soft limit" do
        heroku.should_not_receive(:ps_scale)
        autoscaler.scale(soft_high)
      end

      it "should scale down if below lower soft limit" do
        heroku.should_receive(:ps_scale).with(app_name, hash_including(:qty => 2))
        autoscaler.scale(soft_low)
      end
    end
  end
end
