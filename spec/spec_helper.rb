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

ENV['ETCD_HOST'] ||= '127.0.0.1'
ENV['ETCD_PORT'] ||= '4001'

require 'webmock/rspec'
require 'etcd'
