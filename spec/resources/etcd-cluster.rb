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
    num = node_pids.size
    res = if num == 3
      "UP"
    elsif num > 0 && num < 3
      "PARTIAL"
    elsif num == 0
      "DOWN"
    end
    puts res
  end

  def start
    return puts "ETCD binary not found!" unless is_etcd_installed?
    ensure_data_path
    (1..NODE_COUNT).to_a.each do |i|
      cmd = start_node(i)
      system(cmd)
    end
  end

  def reset
    stop
    `rm -rf #{DATA_PATH}`
  end

  def ensure_data_path
    `mkdir -p #{DATA_PATH}`
  end

  def is_etcd_installed?
    File.exists?(bin_path)
  end

  def start_node(num)
    node_name     = "node#{num}"
    server_port   = SERVER_PORT_BASE + num
    client_port   = CLIENT_PORT_BASE + num
    master_option = ''
    master_option = "-C=127.0.0.1:#{SERVER_PORT_BASE + 1}" if num > 1
    cmd = %Q(#{bin_path} -vv \
        -n=#{node_name} \
        -d=tmp/etcd/#{node_name} \
        -s=127.0.0.1:#{server_port} \
        -c=127.0.0.1:#{client_port}  #{master_option} >> tmp/etcd/#{node_name}.out & 2>&1)
  end

  def stop
    node_pids.each do |pid|
      Process.kill("TERM", pid.to_i)
    end
  end

  def node_pids
    `ps -ef|grep tmp/etcd|grep -v grep`.split("\n").map{|x| x.split[1]}
  end

  def help
    puts "Usage: #{File.basename(__FILE__)} start|stop|status|reset"
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