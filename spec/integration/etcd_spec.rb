# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'With real server an etcd client' do

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

  before(:all) do
    ClusterController.stop_cluster
    ClusterController.start_cluster
    sleep 2 # wait a little for the cluster to come up
  end

  after(:all) do
    ClusterController.stop_cluster
  end

  let :client do
    Etcd::Client.test_client
  end

  before do
    pending('etcd could not be started, check it with `sh/cluster start`') unless client
  end

  before do
    client.delete(key)
  end

  it 'sets and gets the value for a key' do
    client.set(key, 'foo')
    client.get(key).should eq('foo')
  end

  it 'sets a key with a TTL' do
    client.set(key, 'foo', ttl: 5)
    client.info(key)[:ttl].should be_within(1).of(5)
    client.info(key)[:expiration].should be_within(1).of(Time.now + 5)
  end

  it 'watches for changes to a key' do
    Thread.start { sleep(0.1); client.set(key, 'baz') }
    new_value, info = *client.watch(key) { |v, k, info|  [v, info]  }
    new_value.should eq('baz')
    info[:new_key].should eq(true)
  end

  it 'conditionally sets the value for a key' do
    client.set(key, 'bar')
    client.update(key, 'qux', 'baz').should eq(false)
    client.update(key, 'qux', 'bar').should eq(true)
  end

  # FIXME: this test does not pass consistently. There seem to issues
  # with the leader re-election handling (causing Errno::ECONNREFUSED)
  it "has heartbeat, that resets observed watches" do
    client = Etcd::Client.test_client(:heartbeat_freq => 0.1)
    puts client.cluster.nodes.map(&:inspect)
    client.cluster.nodes.map(&:status).uniq.should eq([:running])
    changes = Queue.new

    client.observe('/foo') do |v,k,info|
      puts "triggered #{info.inspect}"
      changes << info
    end

    changes.size.should eq(0)

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
      sleep 0.4
    end

    a.join
    changes.size.should eq(2)

    # restore cluster
    ClusterController.stop_cluster
    ClusterController.start_cluster
    sleep 2
  end
end
