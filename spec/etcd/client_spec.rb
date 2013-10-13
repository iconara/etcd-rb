# encoding: utf-8
require 'spec_helper'

module Etcd
  describe Client do
    include ClusterHelper

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

    def base_uri
      "http://127.0.0.1:4001/v1"
    end

    let :client do
      default_client
    end

    describe '#get' do
      before do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'value' => 'bar'}))
      end

      it 'sends a GET request to retrieve the value for a key' do
        client.get('/foo')
        WebMock.should have_requested(:get, "#{base_uri}/keys/foo")
      end

      it 'prepends a slash to keys when necessary' do
        client.get('foo')
        WebMock.should have_requested(:get, "#{base_uri}/keys/foo")
      end

      it 'parses the response and returns the value' do
        client.get('/foo').should == 'bar'
      end

      it 'returns nil if when the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.get('/foo').should be_nil
      end

      context 'when listing a prefix' do
        it 'returns a hash of keys and their values' do
          values = [
            {'key' => '/foo/bar', 'value' => 'bar'},
            {'key' => '/foo/baz', 'value' => 'baz'},
          ]
          stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump(values))
          client.get('/foo').should eql({'/foo/bar' => 'bar', '/foo/baz' => 'baz'})
        end
      end
    end


    describe '#set' do
      before do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a POST request to set the value for a key' do
        client.set('/foo', 'bar')
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with(body: 'value=bar')
      end

      it 'prepends a slash to keys when necessary' do
        client.set('foo', 'bar')
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with(body: 'value=bar')
      end

      it 'parses the response and returns the previous value' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevValue' => 'baz'}))
        client.set('/foo', 'bar').should == 'baz'
      end

      it 'returns nil when there is no previous value' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
        client.set('/foo', 'bar').should be_nil
      end

      it 'sets a TTL when the :ttl option is given' do
        client.set('/foo', 'bar', ttl: 3)
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with(body: 'value=bar&ttl=3')
      end
    end

    describe '#update' do
      before do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a POST request to set the value conditionally' do
        client.update('/foo', 'bar', 'baz')
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with(body: 'value=bar&prevValue=baz')
      end

      it 'returns true when the key is successfully changed' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
        client.update('/foo', 'bar', 'baz').should be_true
      end

      it 'returns false when an error is returned' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(status: 400, body: MultiJson.dump({}))
        client.update('/foo', 'bar', 'baz').should be_false
      end

      it 'sets a TTL when the :ttl option is given' do
        client.update('/foo', 'bar', 'baz', ttl: 3)
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with(body: 'value=bar&prevValue=baz&ttl=3')
      end
    end


    describe '#delete' do
      before do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a DELETE request to remove a key' do
        client.delete('/foo')
        WebMock.should have_requested(:delete, "#{base_uri}/keys/foo")
      end

      it 'returns the previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevValue' => 'bar'}))
        client.delete('/foo').should == 'bar'
      end

      it 'returns nil when there is no previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.delete('/foo').should be_nil
      end
    end

    describe '#exists?' do
      it 'returns true if the key has a value' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'value' => 'bar'}))
        client.exists?('/foo').should be_true
      end

      it 'returns false if the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.exists?('/foo').should be_false
      end
    end

    describe '#info' do
      it 'returns the key, value, index, expiration and TTL for a key' do
        body = MultiJson.dump({'action' => 'GET', 'key' => '/foo', 'value' => 'bar', 'index' => 31, 'expiration' => '2013-12-11T12:09:08.123+02:00', 'ttl' => 7})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should == '/foo'
        info[:value].should == 'bar'
        info[:index].should == 31
        # rounding because of ruby 2.0 time parsing bug @see https://gist.github.com/mindreframer/6746829
        info[:expiration].to_f.round.should == (Time.utc(2013, 12, 11, 10, 9, 8) + 0.123).to_f.round
        info[:ttl].should == 7
      end

      it 'returns the dir flag' do
        body = MultiJson.dump({'action' => 'GET', 'key' => '/foo', 'dir' => true})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should == '/foo'
        info[:dir].should be_true
      end

      it 'returns only the pieces of information that are returned' do
        body = MultiJson.dump({'action' => 'GET', 'key' => '/foo', 'value' => 'bar', 'index' => 31})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should == '/foo'
        info[:value].should == 'bar'
        info[:index].should == 31
      end

      it 'returns nil when the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.info('/foo').should be_nil
      end

      context 'when listing a prefix' do
        it 'returns a hash of keys and their info' do
          body = MultiJson.dump([
            {'action' => 'GET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 31},
            {'action' => 'GET', 'key' => '/foo/baz', 'value' => 'baz', 'index' => 55},
          ])
          stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
          info = client.info('/foo')
          info['/foo/bar'][:key].should == '/foo/bar'
          info['/foo/baz'][:key].should == '/foo/baz'
          info['/foo/bar'][:value].should == 'bar'
          info['/foo/baz'][:value].should == 'baz'
          info['/foo/bar'][:index].should == 31
          info['/foo/baz'][:index].should == 55
        end
      end
    end

    describe "when cluster leader changes" do
      include ClusterHelper

      let :etcd1_uri do
        "http://127.0.0.1:4001"
      end

      let :etcd2_uri do
        "http://127.0.0.1:4002"
      end

      it "#post - follows redirects and updates the cluster status transparently" do
        with_stubbed_status(etcd1_uri)
        with_stubbed_leaders(healthy_cluster_config)

        client = Etcd::Client.connect(:uris => etcd1_uri)
        client.leader.etcd.should == etcd1_uri
        client.leader.name.should == "node1"

        with_stubbed_leaders(healthy_cluster_changed_leader_config)

        stub_request(:post, "#{etcd1_uri}/v1/keys/foo").to_return(status: 307, headers: {'Location' => "#{etcd2_uri}/v1/keys/foo"})
        stub_request(:post, "#{etcd2_uri}/v1/keys/foo").to_return(body: MultiJson.dump({'value' => 'bar'}))
        client.set("foo", "bar")
        client.leader.etcd.should == etcd2_uri
        client.leader.name.should == "node2"
      end
    end

  end
end
