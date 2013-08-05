# encoding: utf-8

module Etcd
  EtcdError = Class.new(StandardError)
  ConnectionError = Class.new(EtcdError)
end

require 'etcd/version'
require 'etcd/client'