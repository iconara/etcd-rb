# encoding: utf-8

module Etcd
  class Client
    include Etcd::Constants
    include Etcd::Requestable
    include Etcd::Loggable

    attr_accessor :cluster
    attr_accessor :leader
    attr_accessor :seed_uris
    attr_accessor :heartbeat_freq
    attr_accessor :observers
    attr_accessor :status # :up/:down

    def inspect
      %Q(<Etcd::Client #{seed_uris}>)
    end

  end
end

require 'etcd/client/protocol'
require 'etcd/client/observing'
require 'etcd/client/failover'
