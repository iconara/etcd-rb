module ClusterHelper

  # Sample V2 API request/response for cluster members
  # $ curl -L http://127.0.0.1:4001/v2/members
  # {"members":[{"id":"d2356cd527a56a4","name":"node2","peerURLs":["http://127.0.0.1:7002"],"clientURLs":["http://127.0.0.1:4002"]},{"id":"108d26d18c38bf0e","name":"node0","peerURLs":["http://127.0.0.1:7000"],"clientURLs":["http://127.0.0.1:4000"]},{"id":"14306b09b8d69fc4","name":"node1","peerURLs":["http://127.0.0.1:7001"],"clientURLs":["http://127.0.0.1:4001"]}]}

  def status_data
   {"members" =>
     [
       {"id" => "14306b09b8d69fc4","name" => "node1","peerURLs"=> ["http://127.0.0.1:7001"],"clientURLs" => ["http://127.0.0.1:4001"]},
       {"id" => "d2356cd527a56a4","name" => "node2","peerURLs" => ["http://127.0.0.1:7002"],"clientURLs" => ["http://127.0.0.1:4002"]},
       {"id" => "108d26d18c38bf0e","name" => "node3","peerURLs" => ["http://127.0.0.1:7003"],"clientURLs" => ["http://127.0.0.1:4003"]}
     ]
   }
  end

  # cluster config hashes below map member client URLs to the leader client URL

  def healthy_cluster_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:4001',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:4001',
      'http://127.0.0.1:4003' => 'http://127.0.0.1:4001'
    }
  end

  def one_down_cluster_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:4001',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:4001',
      'http://127.0.0.1:4003' => :down
    }
  end

  def healthy_cluster_changed_leader_config
    {
      'http://127.0.0.1:4001' => 'http://127.0.0.1:4002',
      'http://127.0.0.1:4002' => 'http://127.0.0.1:4002',
      'http://127.0.0.1:4003' => 'http://127.0.0.1:4002'
    }
  end

  def with_stubbed_status(uri)
    status_uri = Etcd::Cluster.status_uri(uri)
    stub_request(:get, status_uri).to_return(body: MultiJson.dump(status_data))
    yield if block_given?
    #WebMock.should have_requested(:get, status_uri)
  end


  def leader_uri(uri)
    "#{uri}/v2/members/leader"
  end

  def stub_leader_uri(uri, opts = {})
    leader = (opts[:leader] || "http://127.0.0.1:4001")
    if leader == :down
      stub_request(:get, leader_uri(uri)).to_timeout
    else
      leader_info = status_data["members"].select{|node| node["clientURLs"].first == leader }.first
      stub_request(:get, leader_uri(uri)).to_return(body: MultiJson.dump(leader_info) )
    end
  end

  # [{node_client_url => leader_client_url},{node_client_url => leader_client_url}]
  def with_stubbed_leaders(cluster_config)
    cluster_config.each do |url, leader_uri|
      stub_leader_uri(url, :leader => leader_uri)
    end
    yield if block_given?
    #urls.each { |url| WebMock.should have_requested(:get, leader_uri(url))}
  end
end
