module Etcd
  class Node
    include Etcd::Constants
    include Etcd::Requestable
    attr_accessor :name, :etcd, :raft
    # possible values: :unknown, :running, :down
    attr_accessor :status
    attr_accessor :is_leader

    def initialize(opts={})
      check_required(opts)
      @name   = opts[:name]
      @etcd   = URI.decode(opts[:etcd])
      @raft   = URI.decode(opts[:raft])
      @status = :unknown
    end

    def check_required(opts)
      raise ArgumentError, "etcd URL is required!" unless opts[:etcd]
    end

    def update_status
      begin
        response   = request(:get, leader_uri)
        @status    = :running
        @is_leader = (response.body == @raft)
      rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
        @status = :down
      end
    end

    def leader_uri
      "#{@etcd}/v1/leader"
    end

    def inspect
      %Q(<#{self.class} - #{name_with_status} - #{etcd}>)
    end

    def name_with_status
      print_status = @is_leader ? "leader" : status
      "#{name} (#{print_status})"
    end
  end
end
