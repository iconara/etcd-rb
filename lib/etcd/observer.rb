module Etcd
  class Observer
    include Etcd::Loggable

    def initialize(client, prefix, handler)
      @client  = client
      @prefix  = prefix
      @handler = handler
      @index   = nil
      reset_logger!(Logger::DEBUG)
    end

    def run
      @running = true
      @thread = Thread.start do
        while @running
          logger.debug "********* watching #{@prefix} with index #{@index}"
          @client.watch(@prefix, index: @index) do |value, key, info|
            if @running
              logger.debug "watch fired for #{@prefix} with #{info.inspect} "
              call_handler_in_needed(value, key, info)
            end
          end
        end
      end
      self
    end

    ## etcd has a bug: after restart watches with index fire __sometimes__ with all the previous values
    ## workaround:
    ##  - execute @handler only if info[:index] had higher value than the last index
    def call_handler_in_needed(value, key, info)
      if info[:index] && @index.to_i <= info[:index]
        # next time start watching from next index
        @index = info[:index] + 1
        logger.debug "index for #{@prefix} ----  #{@index} "
        @handler.call(value, key, info)
      # first-time-fire
      elsif @index == nil
        @handler.call(value, key, info)
      end
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
