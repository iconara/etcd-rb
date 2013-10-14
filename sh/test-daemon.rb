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
  #puts "mem:  " + get_memory_usage.to_s + ", heap: " + GC.stat[:heap_free_num].to_s
end


#### test the communication from a console
# client = Etcd::Client.test_client
# key    = "/production/mongodb/master"
# client.set(key, "10.0.0.10:9999")


=begin

mem:  23832, heap: 51283
D, [2013-10-13T22:23:18.331324 #10990] DEBUG -- : rerun for /production/mongodb/master
D, [2013-10-13T22:23:18.333303 #10990] DEBUG -- : after termination for /production/mongodb/master
D, [2013-10-13T22:23:18.334463 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 515
mem:  23820, heap: 51283

----------------------- A BUG HERE !!!!!  Watch with index 515 fires for all the previous key versions!
D, [2013-10-13T22:23:18.582916 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.230:9999", :index=>9, :previous_value=>"10.0.0.222:9999", :action=>:set}
D, [2013-10-13T22:23:18.582994 #10990] DEBUG -- : index for /production/mongodb/master ----  10
switching mongo master to 10.0.0.230:9999
D, [2013-10-13T22:23:18.583052 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 10
D, [2013-10-13T22:23:18.584326 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.244:9999", :index=>10, :previous_value=>"10.0.0.230:9999", :action=>:set}
D, [2013-10-13T22:23:18.584384 #10990] DEBUG -- : index for /production/mongodb/master ----  11
switching mongo master to 10.0.0.244:9999
D, [2013-10-13T22:23:18.584451 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 11
D, [2013-10-13T22:23:18.585447 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.250:9999", :index=>11, :previous_value=>"10.0.0.244:9999", :action=>:set}
D, [2013-10-13T22:23:18.585494 #10990] DEBUG -- : index for /production/mongodb/master ----  12
switching mongo master to 10.0.0.250:9999
D, [2013-10-13T22:23:18.585527 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 12
D, [2013-10-13T22:23:18.586469 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.12:9999", :index=>13, :previous_value=>"10.0.0.250:9999", :action=>:set}
D, [2013-10-13T22:23:18.586515 #10990] DEBUG -- : index for /production/mongodb/master ----  14
switching mongo master to 10.0.0.12:9999
D, [2013-10-13T22:23:18.586567 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 14
D, [2013-10-13T22:23:18.587658 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.18:9999", :index=>14, :previous_value=>"10.0.0.12:9999", :action=>:set}
D, [2013-10-13T22:23:18.587715 #10990] DEBUG -- : index for /production/mongodb/master ----  15
switching mongo master to 10.0.0.18:9999
D, [2013-10-13T22:23:18.587766 #10990] DEBUG -- : ********* watching /production/mongodb/master with index 15
D, [2013-10-13T22:23:18.588826 #10990] DEBUG -- : watch fired for /production/mongodb/master with {:key=>"/production/mongodb/master", :value=>"10.0.0.226:9999", :index=>16, :previous_value=>"10.0.0.18:9999", :action=>:set}
D, [2013-10-13T22:23:18.588873 #10990] DEBUG -- : index for /production/mongodb/master ----  17
switching mongo master to 10.0.0.226:9999


=end