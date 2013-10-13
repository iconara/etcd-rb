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
  GC.start
  puts "mem:  " + get_memory_usage.to_s + ", heap: " + GC.stat[:heap_free_num].to_s
end


#### test the communication from a console
# client = Etcd::Client.test_client
# key    = "/production/mongodb/master"
# client.set(key, "10.0.0.10:9999")