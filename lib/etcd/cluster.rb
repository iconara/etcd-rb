module Etcd
  class Cluster
    attr_accessor :nodes
    attr_accessor :seed_uri

    class << self
      include Etcd::Requestable
      include Etcd::Constants
      include Etcd::Loggable

      # @example
      #   Etcd::Cluster.cluster_status("http://127.0.0.1:4001")
      #
      # @return [Array] of node attributes as [Hash]
      def cluster_status(uri)
        begin
          data = request_data(:get, status_uri(uri))
          parse_cluster_status(data)
        rescue Errno::ECONNREFUSED => e
          logger.debug("cluster_status - error!")
          nil
        end
      end

      def status_uri(uri)
        "#{uri}/v1/keys/_etcd/machines/"
      end

      def parse_cluster_status(cluster_status_response)
        cluster_status_response.map do |attrs|
          node_name = attrs[S_KEY].split(S_SLASH).last
          urls      = attrs[S_VALUE].split(S_AND)
          etcd      = urls.grep(/etcd/).first.split("=").last
          raft      = urls.grep(/raft/).first.split("=").last
          {:name => node_name, :raft => raft, :etcd => etcd}
        end
      end



      # @example
      #   Etcd::Cluster.nodes_from_uri("http://127.0.0.1:4001")
      #
      # @return [Array] of [Node] instances, representing cluster status
      # @see #nodes_from_attributes
      def nodes_from_uri(uri)
        node_attributes = cluster_status(uri)
        nodes_from_attributes(node_attributes)
      end

      def nodes_from_attributes(node_attributes)
        res = node_attributes.map do |attr|
          Etcd::Node.new(attr)
        end
      end

      # creates new cluster with updated status
      # is preferred way to create a cluster instance
      # @example
      #   Etcd::Cluster.init_from_uris("http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003")
      #
      # @return [Cluster] instance with live data in nodes
      def init_from_uris(*uris)
        Array(uris).each do |uri|
          if Etcd::Cluster.cluster_status(uri)
            instance = Etcd::Cluster.new(uri)
            instance.update_status
            return instance
          end
        end
        raise AllNodesDownError, "could not initialize a cluster from #{uris.join(", ")}"
      end
    end

    def initialize(uri)
      @seed_uri = uri
    end

    def nodes
      @nodes ||= update_status
    end

    def update_status
      @nodes = begin
        nodes = Etcd::Cluster.nodes_from_uri(seed_uri)
        nodes.map{|x| x.update_status}
        nodes
      end
    end

    # leader instance in cluster
    # @return [Node]
    def leader
      nodes.select{|x| x.is_leader}.first
    end
  end
end