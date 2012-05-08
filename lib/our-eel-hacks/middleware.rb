require 'our-eel-hacks/autoscaler'

module OurEelHacks
  class Middleware
    def initialize(flavor)
      @flavor = flavor
      @canary_string = "Canary: #{Time.now.to_s}"
    end

    protected

    def autoscale(metric)
      now = Time.now
      canary = @canary_string.dup
      if @scaling_at.nil? or (now - @scaling_at) > 60
        @scaling_at = now
        trigger_scaling(metric, canary)
      end
    end

    def trigger_scaling(metric, canary)
      unless @canary_string == canary
        raise "Canary died: #{@canary_string} != #{canary}"
      end
      Autoscaler.instance_for(@flavor).scale(metric)
      @scaling_at = nil
    end
  end
end
