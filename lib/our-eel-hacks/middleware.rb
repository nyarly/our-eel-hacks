require "heroku"

module OurEelHacks
  class Middleware
    def initialize(flavor)
      @flavor = flavor
    end

    protected

    def autoscale(metric)
      Autoscaler.instance_for(@flavor).scale(metric)
    end
  end
end
