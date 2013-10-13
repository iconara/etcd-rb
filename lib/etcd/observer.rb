module Etcd
  # @private
  class Observer
    def initialize(client, prefix, handler)
      @client  = client
      @prefix  = prefix
      @handler = handler
    end

    def run
      @running = true
      index = nil
      @thread = Thread.start do
        while @running
          logger.debug "starting watching #{@prefix}.. "
          @client.watch(@prefix, index: index) do |value, key, info|
            if @running
              index = info[:index]
              @handler.call(value, key, info)
            end
          end
        end
      end
      self
    end

    def cancel
      @running = false
      self
    end

    def rerun
      logger.debug "rerun for #{@prefix}"
      @thread.terminate if @thread.alive?
      logger.debug "after termination for #{@prefix}"
      run
    end

    def join
      @thread.join
      self
    end

    def logger
      @client.logger
    end
  end
end
