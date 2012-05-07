require 'our-eel-hacks/middleware'
require 'our-eel-hacks/defer/celluloid'

module OurEelHacks
  class Sidekiq < Middleware
    include Defer::Celluloid
    def initialize(flavor=:sidekiq)
      super
    end

    def call(worker_class, item, queue)
      autoscale(get_queue_length(queue))
    ensure
      yield
    end

    def get_queue_length(queue)
      ::Sidekiq.redis do |conn|
        conn.llen("queue:#{queue}") || 0
      end
    end
  end
end
