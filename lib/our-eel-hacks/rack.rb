require 'our-eel-hacks/middleware'
require 'our-eel-hacks/defer/event-machine'
module OurEelHacks
  class Rack < Middleware
    include Defer::EventMachine

    def initialize(app, env_field, flavor = :web)
      super(flavor)
      @env_field = env_field
      @app = app
    end

    def call(env)
      begin
        autoscale(metric_from(env))
      rescue => ex
        puts "Problem in autoscaling: #{ex.inspect}"
      end

      @app.call(env)
    end

    def metric_from(env)
      Integer(env[@env_field]) rescue 0
    end
  end

  class ScaleOnRoutingQueue < Rack
    def initialize(app, flavor = :web)
      super(app, "HTTP_X_HEROKU_QUEUE_DEPTH", flavor)
    end
  end
end
