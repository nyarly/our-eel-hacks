require 'eventmachine'
module OurEelHacks
  module Defer
    module EventMachine
      def trigger_scaling(*args)
        EM.defer do
          super
        end
      end
    end
  end
end
