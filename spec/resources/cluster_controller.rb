class ClusterController

  def self.sh_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', '..', "sh"))
  end

  def self.kill_node(node_name)
    node_pid = `ps -ef|grep etcd|grep #{node_name}|grep -v grep`.split[1]
    `kill -9 #{node_pid}`
  end

  def self.start_cluster
    `#{sh_path}/cluster start`
  end

  def self.stop_cluster
    `#{sh_path}/cluster stop`
  end
end
