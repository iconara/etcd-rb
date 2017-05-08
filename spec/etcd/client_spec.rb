# encoding: utf-8
require 'spec_helper'

module Etcd

  describe Client do
    include ClusterHelper
    include ClientHelper

    def base_uri
      "http://127.0.0.1:4001/v2"
    end

    let :client do
      default_client
    end

    describe '#get' do
      before do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'node' => {'value' => 'bar'}}))
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
        client.get('/foo').should eq('bar')
      end

      it 'returns nil if when the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.get('/foo').should be_nil
      end

      context 'when listing a prefix' do
        it 'returns a hash of keys and their values' do
          values = {'node' => {'nodes' => [
            {'key' => '/foo/bar', 'value' => 'bar'},
            {'key' => '/foo/baz', 'value' => 'baz'}
          ]}}
          stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump(values))
          client.get('/foo').should eql({'/foo/bar' => 'bar', '/foo/baz' => 'baz'})
        end
      end
    end


    describe '#set' do
      before do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevNode' => {'value' => 1}}))
      end

      it 'sends a PUT request to set the value for a key' do
        client.set('/foo', 'bar')
        WebMock.should have_requested(:put, "#{base_uri}/keys/foo").with(body: 'value=bar')
      end

      it 'prepends a slash to keys when necessary' do
        client.set('foo', 'bar')
        WebMock.should have_requested(:put, "#{base_uri}/keys/foo").with(body: 'value=bar')
      end

      it 'parses the response and returns the previous value' do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevNode' => {'value' => 'baz'}}))
        client.set('/foo', 'bar').should eq('baz')
      end

      it 'returns nil when there is no previous value' do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
        client.set('/foo', 'bar').should be_nil
      end

      it 'sets a TTL when the :ttl option is given' do
        client.set('/foo', 'bar', ttl: 3)
        WebMock.should have_requested(:put, "#{base_uri}/keys/foo").with(body: 'value=bar&ttl=3')
      end
    end

    describe '#update' do
      before do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a POST request to set the value conditionally' do
        client.update('/foo', 'bar', 'baz')
        WebMock.should have_requested(:put, "#{base_uri}/keys/foo").with(body: 'value=bar&prevValue=baz')
      end

      it 'returns true when the key is successfully changed' do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
        client.update('/foo', 'bar', 'baz').should eq(true)
      end

      it 'returns false when an error is returned' do
        stub_request(:put, "#{base_uri}/keys/foo").to_return(status: 400, body: MultiJson.dump({}))
        client.update('/foo', 'bar', 'baz').should eq(false)
      end

      it 'sets a TTL when the :ttl option is given' do
        client.update('/foo', 'bar', 'baz', ttl: 3)
        WebMock.should have_requested(:put, "#{base_uri}/keys/foo").with(body: 'value=bar&prevValue=baz&ttl=3')
      end
    end


    describe '#delete' do
      before do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevNode' => {'value' => 1}}))
        stub_request(:delete, "#{base_uri}/keys/foo?recursive=true").to_return(body: MultiJson.dump({'prevNode' => {'value' => 1}}))
      end

      it 'sends a DELETE request to remove a key' do
        client.delete('/foo')
        WebMock.should have_requested(:delete, "#{base_uri}/keys/foo")
      end

      it 'sends a DELETE request to remove a key with args' do
        client.delete('/foo', query: { recursive: true })
        WebMock.should have_requested(:delete, "#{base_uri}/keys/foo?recursive=true")
      end

      it 'returns the previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevNode' => {'value' => 'bar'}}))
        client.delete('/foo').should eq('bar')
      end

      it 'returns nil when there is no previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.delete('/foo').should be_nil
      end
    end

    describe '#exists?' do
      it 'returns true if the key has a value' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'node' => {'value' => 'bar'}}))
        client.exists?('/foo').should eq(true)
      end

      it 'returns false if the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.exists?('/foo').should eq(false)
      end
    end

    describe '#info' do
      it 'returns the key, value, index, expiration and TTL for a key' do
        body = MultiJson.dump({'action' => 'get', 'node' => {'key' => '/foo', 'value' => 'bar', 'index' => 31, 'expiration' => '2013-12-11T12:09:08.123+02:00', 'ttl' => 7}})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should eq('/foo')
        info[:value].should eq('bar')
        info[:index].should eq(31)
        # rounding because of ruby 2.0 time parsing bug @see https://gist.github.com/mindreframer/6746829
        info[:expiration].to_f.round.should eq((Time.utc(2013, 12, 11, 10, 9, 8) + 0.123).to_f.round)
        info[:ttl].should eq(7)
      end

      it 'returns the dir flag' do
        body = MultiJson.dump({'action' => 'get', 'node' => {'key' => '/foo', 'dir' => true}})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should eq('/foo')
        info[:dir].should eq(true)
      end

      it 'returns only the pieces of information that are returned' do
        body = MultiJson.dump({'action' => 'get', 'node' => {'key' => '/foo', 'value' => 'bar', 'index' => 31}})
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
        info = client.info('/foo')
        info[:key].should eq('/foo')
        info[:value].should eq('bar')
        info[:index].should eq(31)
      end

      it 'returns nil when the key does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.info('/foo').should be_nil
      end

      context 'when listing a prefix' do
        it 'returns a hash of keys and their info' do
          body = MultiJson.dump({'node' => {'nodes' => [
            {'action' => 'GET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 31},
            {'action' => 'GET', 'key' => '/foo/baz', 'value' => 'baz', 'index' => 55},
          ]}})
          stub_request(:get, "#{base_uri}/keys/foo").to_return(body: body)
          info = client.info('/foo')
          puts info
          info['/foo/bar'][:key].should eq('/foo/bar')
          info['/foo/baz'][:key].should eq('/foo/baz')
          info['/foo/bar'][:value].should eq('bar')
          info['/foo/baz'][:value].should eq('baz')
          info['/foo/bar'][:index].should eq(31)
          info['/foo/baz'][:index].should eq(55)
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
        client.leader.client_urls.first.should eq(etcd1_uri)
        client.leader.name.should eq("node1")

        with_stubbed_leaders(healthy_cluster_changed_leader_config)

        stub_request(:put, "#{etcd1_uri}/v2/keys/foo").to_return(status: 307, headers: {'Location' => "#{etcd2_uri}/v2/keys/foo"})
        stub_request(:put, "#{etcd2_uri}/v2/keys/foo").to_return(body: MultiJson.dump({'value' => 'bar'}))
        client.set("foo", "bar")
        client.leader.client_urls.first.should eq(etcd2_uri)
        client.leader.name.should eq("node2")
      end
    end

  end
end
