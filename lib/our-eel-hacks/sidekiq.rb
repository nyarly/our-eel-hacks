require 'our-eel-hacks/middleware'
require 'our-eel-hacks/defer/event-machine'

module OurEelHacks
  class Sidekiq < Middleware
    include Defer::EventMachine
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
