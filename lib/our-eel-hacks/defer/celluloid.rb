require 'celluloid'

module OurEelHacks
  module Defer
    module Celluloid
      def trigger_scaling(*args)
        ::Celluloid::Future.new do
          super
        end
      end
    end
  end
end
