module Etcd
  class Heartbeat
    include Etcd::Loggable

    attr_accessor :client
    attr_accessor :freq
    def initialize(client, freq)
      @client = client
      @freq   = freq
    end


    # Initiates heartbeating the leader node in a background thread
    # ensures, that observers are refreshed after leader re-election
    def start_heartbeat_if_needed
      return if freq == 0
      return if @heartbeat_thread
      @heartbeat_thread = Thread.new do
        while true do
          heartbeat_command
        end
      end
    end


    # The command to check leader online status,
    # runs in background and is resilient to failures
    def heartbeat_command
      logger.debug("heartbeat_command: enter ")
      logger.debug(observers_overview.join(", "))
      begin
        client.send(:refresh_observers_if_needed)
        client.update_cluster if client.status == :down
        client.get("foo")
      rescue Exception => e
        client.status = :down
        logger.debug "heartbeat - #{e.message} #{e.backtrace}"
      end
      sleep freq
    end

  end
end