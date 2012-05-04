require 'heroku'

module OurEelHacks
  class Autoscaler
    class << self
      def instance_for(flavor = :web)
        flavor = flavor.to_sym
        @instances ||= {}
        return @instances[flavor] if @instances.has_key?(flavor)

        instance = self.new
        return @instances[flavor] = instance
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
        return value >= @soft and value <= @hard
      end

      def >(value)
        return value > @hard
      end

      def <(value)
        return value < @soft
      end
    end

    class LowerLimit < Limit
      def includes?(value)
        return value >= @hard and value <= @soft
      end

      def >(value)
        return value > @soft
      end

      def <(value)
        return value < @hard
      end
    end

    def initialize()
      @dynos = nil
      @last_scaled = 0
      @entered_soft = nil
      @soft_side = nil
      @last_reading = nil

      @app_name = nil
      @heroku_api_key = nil
      @min_dynos = 1
      @max_dynos = 10

      @lower_limits = LowerLimit.new(5, 1)
      @upper_limits = UpperLimit.new(30, 50)
      @soft_duration = 500
      @scaling_frequency = 200
      @logger = nil

      update_dynos
    end

    def update_dynos
      new_value = current_dynos
      if new_value != dynos
        @last_scaled = Time.now
      end
      @dynos = current_dynos
      @last_reading = Time.now
    end

    def log(msg)
      return if @logger.nil
      @logger.info(msg)
    end

    def configure
      yield self
    end

    attr_accessor :min_dynos, :max_dynos, :lower_limits, :upper_limits, :soft_duration, :scaling_frequency, :logger, :heroku_api_key
    attr_reader :last_scaled, :dynos, :entered_soft, :last_reading

    def scale(metric)
      if (Time.now - last_scaled) * 1000 < scaling_frequency
        return
      end

      target_dynos = target_scale(metric)

      target_dynos = [[target_dynos, max_dynos].min, min_dynos].max

      set_dynos(target_dynos)

      update_dynos
    end

    def target_scale(metric)
      if metric < lower_limits
        return dynos - 1
      elsif metric > upper_limits
        return dynos + 1
      elsif
        return dynos + soft_limit(metric)
      end
    end

    def soft_limit(metric, limits)
      hit_limit = [lower_limits, upper_limits].find{|lim| lim.include? metric}

      if soft_side == hit_limit
        if (entered_soft - Time.now) * 1000 > soft_duration
          entered_soft = Time.now
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
      end

      @soft_side = hit_limit
      entered_soft = Time.now
      return 0
    end

    def current_dynos
      heroku.info(app_name])[:dynos].to_i
    end

    def heroku
      @heroku ||= Heroku::Client.new("", heroku_api_key)
    end

    def set_dynos(count)
      return if count == dynos
      heroku.set_dynos(app_name], count)
      @last_scaled = Time.now
    end
  end
end
