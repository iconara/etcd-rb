module Etcd
  class Node
    include Etcd::Constants
    include Etcd::Requestable
    attr_accessor :name, :id, :peer_urls, :client_urls
    # possible values: :unknown, :running, :down
    attr_accessor :status
    attr_accessor :is_leader

    class << self
      def parse_node_data(attrs)
        {
          :id          => attrs["id"],
          :name        => attrs["name"],
          :peer_urls   => attrs["peerURLs"],
          :client_urls => attrs["clientURLs"]
        }
      end
    end

    def initialize(opts={})
      check_required(opts)
      @name        = opts[:name]
      @id          = opts[:id]
      @peer_urls   = opts[:peer_urls]
      @client_urls = opts[:client_urls]
      @status = :unknown
    end

    def check_required(opts)
      raise ArgumentError, "Client URL is required!" unless opts[:client_urls] && opts[:client_urls].any?
      raise ArgumentError, "Node ID is required!" unless opts[:id]
    end

    def update_status
      begin
        leader_data = request_data(:get, leader_uri)
        @status     = :running
        @is_leader  = (leader_data["id"] == @id)
      rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
        @status = :down
      end
    end

    def leader_uri
      "#{@client_urls.first}/v2/members/leader"
    end

    def inspect
      %Q(<#{self.class} - #{id} - #{name_with_status} - #{peer_urls}>)
    end

    def name_with_status
      print_status = @is_leader ? "leader" : status
      "#{name} (#{print_status})"
    end

    def to_json
      { :name => name, :id => id, :client_urls => client_urls, :peer_urls => peer_urls }.to_json
    end
  end
end
