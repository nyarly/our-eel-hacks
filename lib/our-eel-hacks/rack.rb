require 'our-eel-hacks/middleware'
require 'our-eel-hacks/defer/event-machine'
module OurEelHacks
  class Rack < Middleware
    include Defer::EventMachine

    def initialize(app, env_fields, flavor = :web)
      super(flavor)
      @env_fields = [*env_fields].map(&:to_s)
      @app = app
    end

    def call(env)
      begin
        autoscale(metrics_from(env))
      rescue => ex
        puts "Problem in autoscaling: #{ex.inspect}"
      end

      @app.call(env)
    end

    def metrics_from(env)
      Hash[ @env_fields.map do |field|
        [field, (Integer(env[field]) rescue 0)]
      end ]
    end
  end

  class ScaleOnRoutingQueue < Rack
    def initialize(app, flavor = :web)
      super(app, "HTTP_X_HEROKU_QUEUE_DEPTH", flavor)
    end
  end
end
