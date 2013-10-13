# encoding: utf-8

module Etcd
  EtcdError         = Class.new(StandardError)
  ConnectionError   = Class.new(EtcdError)
  AllNodesDownError = Class.new(EtcdError)
end

require 'time'
require 'thread'
require 'httpclient'
require 'multi_json'
require 'logger'

require 'etcd/version'
require 'etcd/constants'
require 'etcd/requestable'
require 'etcd/node'
require 'etcd/cluster'
require 'etcd/observer'
require 'etcd/client'
