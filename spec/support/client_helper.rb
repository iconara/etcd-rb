module ClientHelper
  def default_client(uri = "http://127.0.0.1:4001")
    client         = Etcd::Client.new(:uris => uri)
    client.cluster = healthy_cluster(uri)
    client
  end

  # manually construct a valid cluster object
  # clumsy, but works atm
  def healthy_cluster(uri = "http://127.0.0.1:4001")
    data    = Etcd::Cluster.parse_cluster_status(status_data)
    nodes   = Etcd::Cluster.nodes_from_attributes(data)
    cluster = Etcd::Cluster.new(uri)
    cluster.nodes = nodes
    nodes.map{|x| x.status = :running}
    nodes.first.is_leader = true
    cluster
  end
end