require 'our-eel-hacks/autoscaler'

module OurEelHacks
  class Middleware
    def initialize(flavor)
      @flavor = flavor
    end

    protected

    def autoscale(metric)
      now = Time.now
      if @scaling_at.nil? or (now - @scaling_at) > 60
        @scaling_at = now
        trigger_scaling(metric)
      end
    end

    def trigger_scaling(metric)
      Autoscaler.instance_for(@flavor).scale(metric)
      @scaling_at = nil
    end
  end
end
