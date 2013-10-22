require 'bundler'
Bundler.setup
puts "LOADING Etcd-Rb"
require 'etcd'
require 'json'

## only for testing in the console
require './spec/support/common_helper'