require 'bundler'
puts "LOADING Etcd-Rb"
require 'etcd'
require 'json'

## only for testing in the console
require './spec/resources/node_killer'

class Etcd::Client
  def self.test_client
    seed_uris = ["http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003"]
    client = Etcd::Client.connect(:uris => seed_uris)
  end
end