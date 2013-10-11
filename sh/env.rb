require 'bundler'
puts "LOADING Etcd-Rb"
require 'etcd'
require 'json'

## only for testing in the console
require './spec/resources/node_killer'