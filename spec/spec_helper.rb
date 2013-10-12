# encoding: utf-8

require 'bundler/setup'

unless ENV['COVERAGE'] == 'no'
  require 'coveralls'
  require 'simplecov'

  if ENV.include?('TRAVIS')
    Coveralls.wear!
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  end

  SimpleCov.start do
    add_group 'Source', 'lib'
    add_group 'Unit tests', 'spec/etcd'
    add_group 'Integration tests', 'spec/integration'
  end
end

require 'webmock/rspec'
require 'etcd'
require 'json'
require './spec/resources/cluster_controller'

class Etcd::Client
  def self.test_client(opts = {})
    seed_uris = ["http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003"]
    opts.merge!(:uris => seed_uris)
    client = Etcd::Client.connect(opts)
  end
end

Dir["./spec/support/*.rb"].each { |f|  require f}
