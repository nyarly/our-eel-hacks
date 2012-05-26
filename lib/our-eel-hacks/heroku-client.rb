require 'heroku/api'
module OurEelHacks
  class HerokuClient
    def initialize(logger, api_key)
      @logger = logger
      @api = Heroku::API.new(:api_key => api_key)
    end

    attr_reader :logger
    attr_reader :api

    def ps(app_name)
      logger.info{ "Scaling Heroku API call: get ps #{app_name.inspect}" }
      api.get_ps(app_name).body
    end

    def ps_scale(app_name, ps_type, count)
      logger.info{ "Scaling Heroku API call: post ps_scale #{[app_name, ps_type, count].inspect}" }
      api.post_ps_scale(app_name, ps_type, count)
    end
  end
end
