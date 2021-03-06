require 'our-eel-hacks/rack'
require 'logger'

describe OurEelHacks::Autoscaler do
  use_vcr_cassette "OurEelHacks"

  let :app_name do
    "sbmp"
  end

  let :api_key do
    "FakeApiKey"
  end

  let :scaling_freq do
    2500
  end

  let :soft_dur do
    8000
  end

  let :ideal_value do
    { "metric" => 25 }
  end

  let :soft_high do
    { "metric" => 35 }
  end

  let :soft_low do
    { "metric" => 3 }
  end

  let :hard_high do
    { "metric" => 100 }
  end

  let :hard_low do
    { "metric" => -10 }
  end

  let :dyno_count do
    3
  end

  let :expected_scale_frequency do
    scaling_freq * dyno_count
  end

  let! :starting_time do
    Time.now
  end

  before :each do
    @time_index = 0
  end

  def time_adjust(millis)
    @time_index = millis
    Time.stub!(:now).and_return(Time.at(starting_time, millis * 1000))
  end

  def time_advance(millis)
    time_adjust(@time_index + millis)
  end

  let :logger do
    Logger.new($stdout).tap{|lgr| lgr.level = Logger::DEBUG }
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

        #JDL: useful for debugging spec fails
        #Irritating in general use
        #test.logger = logger
      end
    end
  end

  let :heroku do
    autoscaler.heroku
  end

  it "should get a count of dynos at start" do
    autoscaler.dynos.should == dyno_count #comes from the VCR cassette
  end

  before :each do
    OurEelHacks::HerokuClient.processing_budget = 3
    heroku.stub!(:ps_scale)
    time_adjust(0)
    autoscaler.scale(ideal_value)
  end

  def no_requests
    OurEelHacks::HerokuClient.processing_budget = 0
    heroku.should_not_receive(:ps_scale)
    heroku.should_not_receive(:ps)
  end

  describe "scaling frequency" do

    it "should not scale too soon" do
      time_adjust(expected_scale_frequency - 5)

      no_requests
      autoscaler.scale(hard_high)
      autoscaler.scale(hard_high)
      autoscaler.scale(hard_high)
      autoscaler.scale(hard_high)
    end

    it "should scale up if time has elapsed and hard limit exceeded" do
      time_adjust(expected_scale_frequency + 5)

      heroku.should_receive(:ps_scale).with(app_name, "web", 4)
      autoscaler.scale(hard_high)
    end

    it "should not reconsider scaling even if we don't scale" do
      time_advance(expected_scale_frequency + 5)
      expect do
        autoscaler.scale(ideal_value)
      end.to change(autoscaler, :last_scaled)

      no_requests
      time_advance(expected_scale_frequency - 10)
      autoscaler.scale(ideal_value)
    end
  end

  describe "hard limits" do
    before :each do
      time_adjust(expected_scale_frequency + 5)
    end

    it "should scale down if hard lower limit exceeded" do
      heroku.should_receive(:ps_scale).with(app_name, "web", 2)
      autoscaler.scale(hard_low)
    end

    it "should adjust its timing to break cadence after scaling down", :pending => "building VCR cassette" do
      autoscaler.scale(hard_low)
      autoscaler.millis_til_next_scale.should < expected_scale_frequency
      autoscaler.millis_til_next_scale.should > 2 * scaling_freq

      time_advance(autoscaler.millis_til_next_scale + 5)

      autoscaler.scale(ideal_value)

      autoscaler.millis_til_next_scale.should == 2 * scaling_freq

      time_advance((2 * scaling_freq) + 5)

      autoscaler.scale(hard_low)
      autoscaler.millis_til_next_scale.should < 2 * scaling_freq
      autoscaler.millis_til_next_scale.should > scaling_freq
    end
  end

  describe "soft upper limit" do
    before :each do
      time_adjust(expected_scale_frequency * 2)
      autoscaler.scale(soft_high)
    end

    describe "if soft_duration hasn't elapsed" do
      before :each do
        time_adjust((expected_scale_frequency * 2) + soft_dur - 5)
        heroku.should_not_receive(:ps_scale)
      end

      it "should not scale up" do
        autoscaler.scale(soft_high)
        autoscaler.scale(soft_high)
        autoscaler.scale(soft_high)
      end

      it "should not scale down" do
        autoscaler.scale(soft_low)
        autoscaler.scale(soft_high)
        autoscaler.scale(soft_high)
      end
    end

    describe "if soft_duration has elapsed" do
      before :each do
        time_adjust(expected_scale_frequency * 2 + soft_dur + 5)
      end

      it "should scale up if above upper soft limit" do
        heroku.should_receive(:ps_scale).with(app_name, "web", 4)
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
      time_adjust(expected_scale_frequency * 2)
      autoscaler.scale(soft_low)
    end

    describe "if soft_duration hasn't elapsed" do
      before :each do
        time_adjust(expected_scale_frequency * 2 + soft_dur - 5)
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
        time_adjust(expected_scale_frequency * 2 + soft_dur + 5)
      end

      it "should not scale up even if above upper soft limit" do
        heroku.should_not_receive(:ps_scale)
        autoscaler.scale(soft_high)
      end

      it "should scale down if below lower soft limit" do
        heroku.should_receive(:ps_scale).with(app_name, "web", 2)

        autoscaler.scale(soft_low)
      end
    end
  end
end
