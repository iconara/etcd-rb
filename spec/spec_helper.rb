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

Dir["./spec/support/*.rb"].each { |f|  require f}
