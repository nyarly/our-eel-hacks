require 'heroku'

module OurEelHacks
  class HerokuClient < ::Heroku::Client
    def initialize(*args)
      @logger = args.shift
      super(*args)
    end

    attr_reader :logger

    def process(*args, &block)
      logger.info{ "Heroku API call: #{args.inspect}" }
      super
    end
  end
end
