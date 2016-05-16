module ClientHelper
  # Sample V2 API request/response for keys
  # $ curl -L http://127.0.0.1:4001/v2/keys
  # {"action":"get","node":{"dir":true,"nodes":[{"key":"/foo","value":"bar","modifiedIndex":22,"createdIndex":22}]}}

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
    nodes.map{|node| node.status = :running}
    nodes.first.is_leader = true
    cluster
  end
end
