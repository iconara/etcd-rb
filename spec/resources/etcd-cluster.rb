#!/usr/bin/env ruby

class EtcdCluster
  NODE_COUNT       = 3
  DATA_PATH        = "tmp/etcd"
  HOSTNAME         = "127.0.0.1"
  CLIENT_PORT_BASE = 4000
  SERVER_PORT_BASE = 7000

  def bin_path
    '/usr/local/bin/etcd'
  end

  def status
    puts "status"
  end

  def start
    puts "start"
    (1..NODE_COUNT).to_a.each do |i|
      puts start_node(i)
    end
  end

  def start_node(num)
    node_name = "node#{num}"
    %Q(/usr/local/bin/etcd -vv \
        -n=#{node_name} \
        -d=tmp/etcd/#{node_name} \
        -s=127.0.0.1:7001 \
        -c=127.0.0.1:4001 >> tmp/etcd/#{node_name}.out & 2>&1)
  end

  def stop
    puts "stop"
  end

  def help
    puts "Usage: #{File.basename(__FILE__)} start|stop|status|reset|leader|machines"
    puts "       start requires ETCD_HOME to be set"
    exit 1
  end
end


cluster = EtcdCluster.new

case ARGV[0]
  when 'start'  then cluster.start
  when 'stop'   then cluster.stop
  when 'status' then cluster.status
  when 'reset'  then cluster.reset
  else cluster.help
end