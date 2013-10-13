module Etcd
  # @private
  class Observer
    include Etcd::Loggable

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

    def status
      "#{@prefix}: #{thread_status}"
    end

    def thread_status
      st = @thread.status
      st = 'dead by exeption'    if st == nil
      st = 'dead by termination' if st == false
      st
    end

    def logger
      @client.logger
    end
  end
end
