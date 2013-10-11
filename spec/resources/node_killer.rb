class ClusterController
  def self.kill_node(node_name)
    node_pid = `ps -ef|grep #{node_name}|grep -v grep`.split[1]
    `kill -9 #{node_pid}`
  end

  def self.start_cluster
    `sh/start_cluster`
  end
end