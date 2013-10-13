module Etcd
  class Client


    # @param options [Hash]
    # @option options [Array] :uris (['http://127.0.0.1:4001']) seed uris with etcd cluster nodes
    # @option options [Float] :heartbeat_freq (0.0) check-frequency for leader status (in seconds)
    #  Heartbeating will start only for non-zero values
    def initialize(options={})
      @observers      = {}
      @seed_uris      = options[:uris] || ['http://127.0.0.1:4001']
      @heartbeat_freq = options[:heartbeat_freq].to_f
      http_client.redirect_uri_callback = method(:handle_redirected)
    end

    # Create a new client and connect it to the etcd cluster.
    #
    # This method is the preferred way to create a new client, and is the
    # equivalent of `Client.new(options).connect`. See {#initialize} and
    # {#connect} for options and details.
    #
    # @see #initialize
    # @see #connect
    def self.connect(options={})
      self.new(options).connect
    end

    # Connects to the etcd cluster
    #
    # @see #update_cluster
    def connect
      update_cluster
      start_heartbeat_if_needed
      self
    end


    # Creates a Cluster-instance from `@seed_uris`
    # and stores the cluster leader information
    def update_cluster
      logger.debug("update_cluster: enter")
      begin
        @cluster = Etcd::Cluster.init_from_uris(*seed_uris)
        @leader  = @cluster.leader
        @status  = :up
        logger.debug("update_cluster: after success")
        refresh_observers
        @cluster
      rescue AllNodesDownError => e
        logger.debug("update_cluster: failed")
        raise e
      end
    end

    # kinda magic accessor-method:
    # - will reinitialize leader && cluster if needed
    def leader
      @leader ||= cluster && cluster.leader || update_cluster && self.leader
    end

    def leader_uri
      leader && leader.etcd
    end


    def start_heartbeat_if_needed
      logger.debug("client - starting heartbeat")
      @heartbeat = Etcd::Heartbeat.new(self, @heartbeat_freq)
      @heartbeat.start_heartbeat_if_needed
    end

    # Only happens on attempted write to a follower node in cluster. Means:
    # - leader changed since last update
    # Solution: just get fresh cluster status
    def handle_redirected(uri, response)
      update_cluster
      http_client.default_redirect_uri_callback(uri, response)
    end


private
    # :uri and :request_data are the only methods calling :leader method
    # so they both need to handle the case for missing leader in cluster
    def uri(key, action=S_KEYS)
      raise AllNodesDownError unless leader
      key = "/#{key}" unless key.start_with?(S_SLASH)
      "#{leader_uri}/v1/#{action}#{key}"
    end


    def request_data(method, uri, args={})
      logger.debug("request_data:  #{method} - #{uri} #{args.inspect}")
      begin
        super
      rescue Errno::ECONNREFUSED, HTTPClient::TimeoutError => e
        logger.debug("request_data:  re-election handling")
        old_leader_uri = @leader.etcd
        update_cluster
        if @leader
          uri = uri.gsub(old_leader_uri, @leader.etcd)
          retry
        else
          raise AllNodesDownError
        end
      end
    end

  end
end