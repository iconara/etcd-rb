# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'With real server an etcd client' do

  let :client do
    Etcd::Client.test_client
  end

  let :prefix do
    "/etcd-rb/#{rand(234234)}"
  end

  let :key do
    "#{prefix}/hello"
  end

  before do
    WebMock.disable!
    WebMock.allow_net_connect!
  end

  before do
    ClusterController.start_cluster
  end

  before do
    pending('etcd could not be started, check it with `sh/cluster start`') unless client.leader
  end

  before do
    client.delete(key)
  end

  it 'sets and gets the value for a key' do
    client.set(key, 'foo')
    client.get(key).should == 'foo'
  end

  it 'sets a key with a TTL' do
    client.set(key, 'foo', ttl: 5)
    client.info(key)[:ttl].should be_within(1).of(5)
    client.info(key)[:expiration].should be_within(1).of(Time.now + 5)
  end

  it 'watches for changes to a key' do
    Thread.start { sleep(0.1); client.set(key, 'baz') }
    new_value, info = *client.watch(key) { |v, k, info|  [v, info]  }
    new_value.should == 'baz'
    info[:new_key].should == true
  end

  it 'conditionally sets the value for a key' do
    client.set(key, 'bar')
    client.update(key, 'qux', 'baz').should be_false
    client.update(key, 'qux', 'bar').should be_true
  end


  it "has heartbeat, that resets observed watches" do
    ClusterController.start_cluster
    client = Etcd::Client.test_client(:heartbeat_freq => 0.2)
    client.cluster.nodes.map(&:status).uniq.should == [:running]
    changes = Queue.new

    client.observe('/foo') do |v,k,info|
      puts "triggered #{info.inspect}"
      changes << info
    end

    changes.size.should == 0

    ### simulate second console
    a = Thread.new do
      client = Etcd::Client.test_client
      ClusterController.kill_node(client.cluster.leader.name)
      sleep 0.4
      puts "1.st try"
      client.set("/foo", "bar")
      sleep 0.4
      puts "2.nd try"
      client.set("/foo", "barss")
    end

    sleep 1.5
    changes.size.should == 2
  end
end