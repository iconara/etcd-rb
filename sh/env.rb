require 'bundler'
puts "LOADING Etcd-Rb"
require 'etcd'
require 'json'

## only for testing in the console
require './spec/resources/cluster_controller'

class Etcd::Client
  def self.test_client(opts = {})
    seed_uris = ["http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003"]
    opts.merge!(:uris => seed_uris)
    client = Etcd::Client.connect(opts)
  end
end