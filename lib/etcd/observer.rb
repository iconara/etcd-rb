module Etcd
  # @private
  class Observer
    include Etcd::Loggable

    def initialize(client, prefix, handler)
      @client  = client
      @prefix  = prefix
      @handler = handler
      @index   = nil
    end

    def run
      @running = true
      @thread = Thread.start do
        while @running
          logger.debug "starting watching #{@prefix}.. "
          @client.watch(@prefix, index: @index) do |value, key, info|
            if @running
              @index = info[:index]
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
      @thread.status
    end

    def pp_status
      "#{@prefix}: #{pp_thread_status}"
    end

    def pp_thread_status
      st = @thread.status
      st = 'dead by exception'   if st == nil
      st = 'dead by termination' if st == false
      st
    end
  end
end
