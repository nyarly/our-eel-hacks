require 'eventmachine'
module OurEelHacks
  module Defer
    module EventMachine
      def trigger_scaling(*args)
        if ::EM.reactor_running?
          ::EM.defer do
            super
          end
        else
          super
        end
      end
    end
  end
end
