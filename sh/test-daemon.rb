#!/usr/bin/env ruby

require './sh/env'

client = Etcd::Client.test_client(:heartbeat_freq => 1)
key    = "/production/mongodb/master"
puts "observing #{key}"

obs = client.observe(key) do |v,k,info|
  puts "switching mongo master to #{v}"
end


def get_memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i
end

while true
  sleep 1
  puts get_memory_usage
  puts GC.stat
  GC.start
  puts GC.stat
end


#### test the communication from a console
# client = Etcd::Client.test_client
# key    = "/production/mongodb/master"
# client.set(key, "10.0.0.10:9999")