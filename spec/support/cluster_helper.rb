module ClusterHelper
  def status_data
    {"node" =>
      {"nodes" => 
        [
          {
          "key"=>"/_etcd/machines/node1",
          "value"=>
           "raft=http://127.0.0.1:7001&etcd=http://127.0.0.1:4001&raftVersion=v0.1.1",
          "index"=>360},
         {
          "key"=>"/_etcd/machines/node2",
          "value"=>
           "raft=http://127.0.0.1:7002&etcd=http://127.0.0.1:4002&raftVersion=v0.1.1",
          "index"=>360},
         {
          "key"=>"/_etcd/machines/node3",
          "value"=>
           "raft=http://127.0.0.1:7003&etcd=http://127.0.0.1:4003&raftVersion=v0.1.1",
          "index"=>360}
        ]
      }
    }
  end

  def healthy_cluster_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:7001',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:7001',
      'http://127.0.0.1:4003' => 'http://127.0.0.1:7001'
    }
  end

  def one_down_cluster_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:7001',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:7001',
      'http://127.0.0.1:4003' => :down
    }
  end

  def healthy_cluster_changed_leader_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:7002',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:7002',
      'http://127.0.0.1:4003' => 'http://127.0.0.1:7002'
    }
  end

  def with_stubbed_status(uri)
    status_uri = Etcd::Cluster.status_uri(uri)
    stub_request(:get, status_uri).to_return(body: MultiJson.dump(status_data))
    yield if block_given?
    #WebMock.should have_requested(:get, status_uri)
  end


  def leader_uri(uri)
    "#{uri}/v2/leader"
  end

  def stub_leader_uri(uri, opts = {})
    leader = (opts[:leader] ||"http://127.0.0.1:7001")
    if leader == :down
      stub_request(:get, leader_uri(uri)).to_timeout
    else
      stub_request(:get, leader_uri(uri)).to_return(body: leader)
    end
  end

  # [{etcd_url => leader_string},{etcd_url => leader_string}]
  def with_stubbed_leaders(cluster_config)
    cluster_config.each do |url, leader_uri|
      stub_leader_uri(url, :leader => leader_uri)
    end
    yield if block_given?
    #urls.each { |url| WebMock.should have_requested(:get, leader_uri(url))}
  end
end
