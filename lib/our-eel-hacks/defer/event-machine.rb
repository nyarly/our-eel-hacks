require 'eventmachine'
module OurEelHacks
  module Defer
    module EventMachine
      def autoscale(*args)
        EM.defer do
          super
        end
      end
    end
  end
end
