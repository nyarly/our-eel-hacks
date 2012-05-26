require 'our-eel-hacks/heroku-client'

module OurEelHacks
  class NullLogger
    def debug; end
    def info; end
    def warn; end
    def fatal; end
  end

  class Autoscaler
    class << self
      def get_instance(flavor)
        flavor = flavor.to_sym
        @instances ||= Hash.new{ |h,k| h[k] = self.new }
        return @instances[flavor]
      end

      def configure(flavor = :web, &block)
        get_instance(flavor).configure(flavor, &block)
      end

      def instance_for(flavor = :web)
        instance = get_instance(flavor)
        instance.check_settings
        return instance
      end
    end

    class Limit
      def initialize(soft, hard)
        @soft = soft
        @hard = hard
      end

      attr_accessor :hard, :soft
    end

    class UpperLimit < Limit
      def includes?(value)
        return (@soft < value && value <= @hard)
      end

      def >(value)
        return @soft > value
      end

      def <(value)
        return @hard < value
      end
    end

    class LowerLimit < Limit
      def includes?(value)
        return (value >= @hard && value <= @soft)
      end

      def >(value)
        return @hard > value
      end

      def <(value)
        return @soft < value
      end
    end

    def initialize()
      @dynos = nil
      @soft_side = nil

      @memoed_dyno_info = nil

      @last_scaled = Time.at(0)
      @entered_soft = Time.at(0)
      @last_reading = nil

      @app_name = nil
      @ps_type = nil
      @heroku_api_key = nil

      @min_dynos = 1
      @max_dynos = 10
      @lower_limits = LowerLimit.new(5, 1)
      @upper_limits = UpperLimit.new(30, 50)

      @soft_duration = 10000
      @scaling_frequency = 5000
      @heroku_rate_limit = 80_000
      @heroku_rate_limit_margin = 0.1

      @millis_til_next_scale = nil

      @logger = NullLogger.new
    end

    def configure(flavor = nil)
      yield self
      check_settings
      logger.info{ "Autoscaler configured for #{flavor || "{{unknown flavor}}"}"}

      update_dynos(dyno_info.count, Time.now)
      update_scaling_delay(0)
    end

    MILLIS_PER_DAY = 24 * 60 * 60 * 1000
    def check_settings
      errors = []
      errors << "No heroku api key set" if @heroku_api_key.nil?
      errors << "No app name set" if @app_name.nil?
      errors << "No process type set" if @ps_type.nil?
      if (MILLIS_PER_DAY / @heroku_rate_limit) *
        (1.0 - @heroku_rate_limit_margin) *
        API_CALLS_PER_SCALE > @scaling_frequency
        errors << "Scaling frequency will lock up Heroku"
      end
      unless errors.empty?
        logger.warn{ "Problems configuring Autoscaler: #{errors.inspect}" }
        raise "OurEelHacks::Autoscaler, configuration problem: " + errors.join(", ")
      end
    end

    attr_accessor :min_dynos, :max_dynos, :lower_limits, :upper_limits, :ps_type,
      :soft_duration, :scaling_frequency, :logger, :heroku_api_key, :app_name, :heroku_rate_limit, :heroku_rate_limit_margin
    attr_reader :last_scaled, :dynos, :entered_soft, :last_reading, :soft_side, :millis_til_next_scale

    def elapsed(start, finish)
      seconds = finish.to_i - start.to_i
      micros = finish.usec - start.usec
      diff = seconds * 1000 + micros / 1000
      logger.debug{ "Elapsed: #{start.to_s}:#{finish.to_s} : #{diff}ms" }
      return diff
    end

    API_CALLS_PER_SCALE = 2
    def scale(metric_hash)
      logger.debug{ "Scaling request for #{@ps_type}: metrics are: #{metric_hash.inspect}" }

      #TODO: multi-metric scaling logic
      metric = metric_hash.to_a.last.last #Yeah, this is awful
      moment = Time.now
      if elapsed(last_scaled, moment) < millis_til_next_scale
        logger.debug{ "Not scaling: elapsed #{elapsed(last_scaled, moment)} less than computed #{millis_til_next_scale}" }
        return
      end

      clear_dyno_info

      starting_wait = millis_til_next_scale

      update_dynos(dyno_info.count, moment)

      target_dynos = target_scale(metric, moment)

      target_dynos = [[target_dynos, max_dynos].min, min_dynos].max
      logger.debug{ "Target dynos at: #{min_dynos}/#{target_dynos}/#{max_dynos} (vs. current: #{@dynos})" }

      set_dynos(target_dynos, moment)

      update_scaling_delay(starting_wait)
    rescue => ex
      logger.warn{ "Problem scaling: #{ex.inspect} \t#{ex.backtrace.join("\t\n")}" }
    end

    def target_scale(metric, moment)
      if lower_limits > metric
        return dynos - 1
      elsif upper_limits < metric
        return dynos + 1
      elsif
        result = (dynos + soft_limit(metric, moment))
        return result
      end
    end

    def soft_limit(metric, moment)
      hit_limit = [lower_limits, upper_limits].find{|lim| lim.includes? metric}

      if soft_side == hit_limit
        if elapsed(entered_soft, moment) > soft_duration
          entered_soft = moment
          case hit_limit
          when upper_limits
            return +1
          when lower_limits
            return -1
          else
            return 0
          end
        else
          return 0
        end
      else
        @entered_soft = moment
      end

      @soft_side = hit_limit
      return 0
    end

    def update_scaling_delay(starting_wait)
      @millis_til_next_scale = scaling_frequency * @dynos
      if starting_wait > millis_til_next_scale
        logger.debug{ "Adjusting scaling delay for cadence between #{@millis_til_next_scale.inspect} and #{starting_wait.inspect}" }
        @millis_til_next_scale += rand(starting_wait - @millis_til_next_scale)
      end
    end

    def update_dynos(new_value, moment)
      if new_value != dynos
        @last_scaled = moment
        @entered_soft = moment
      end
      @dynos = new_value
      @last_reading = moment
    end

    def clear_dyno_info
      @memoed_dyno_info = nil
    end

    def dyno_info
      return @memoed_dyno_info ||=
        begin
          regexp = /^#{ps_type}[.].*/
          heroku.ps(app_name).find_all do |dyno|
            dyno["process"] =~ regexp
          end
        end
    end

    def dynos_stable?
      return dyno_info.all? do |dyno|
        dyno["state"] == "up"
      end
    end

    def heroku
      @heroku ||= HerokuClient.new(logger, "", heroku_api_key)
    end

    def set_dynos(count,moment)
      if count == dynos
        logger.debug{ "Not scaling: #{count} ?= #{dynos}" }
        return
      end

      if not (stable = dynos_stable?)
        logger.debug{ "Not scaling: dynos not stable (iow: not all #{ps_type} dynos are up)" }
        return
      end
      logger.info{ "Scaling from #{dynos} to #{count} dynos for #{ps_type}" }
      heroku.ps_scale(app_name, :type => ps_type, :qty => count)
      update_dynos(count, moment)
    end
  end
end
