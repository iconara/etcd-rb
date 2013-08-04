# encoding: utf-8

module Etcd
  EtcdError = Class.new(StandardError)
end

require 'etcd/version'
require 'etcd/client'