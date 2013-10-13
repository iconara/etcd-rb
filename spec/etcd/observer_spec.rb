# encoding: utf-8
require 'spec_helper'

module Etcd
  describe Client do
    include ClusterHelper
    include ClientHelper

    def base_uri
      "http://127.0.0.1:4001/v1"
    end

    let :client do
      default_client
    end

    describe '#watch' do
      it 'sends a GET request for a watch of a key prefix' do
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: MultiJson.dump({}))
        client.watch('/foo') { }
        WebMock.should have_requested(:get, "#{base_uri}/watch/foo").with(query: {})
      end

      it 'sends a GET request for a watch of a key prefix from a specified index' do
        stub_request(:post, "#{base_uri}/watch/foo").with(query: {'index' => 3}).to_return(body: MultiJson.dump({}))
        client.watch('/foo', index: 3) { }
        WebMock.should have_requested(:post, "#{base_uri}/watch/foo").with(query: {'index' => 3})
      end

      it 'yields the value' do
        body = MultiJson.dump({'value' => 'bar'})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        value = nil
        client.watch('/foo') do |v|
          value = v
        end
        value.should == 'bar'
      end

      it 'yields the changed key' do
        body = MultiJson.dump({'key' => '/foo/bar', 'value' => 'bar'})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        key = nil
        client.watch('/foo') do |_, k|
          key = k
        end
        key.should == '/foo/bar'
      end

      it 'yields info about the key, when it is a new key' do
        body = MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 3, 'newKey' => true})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        info = nil
        client.watch('/foo') do |_, _, i|
          info = i
        end
        info[:action].should == :set
        info[:key].should == '/foo/bar'
        info[:value].should == 'bar'
        info[:index].should == 3
        info[:new_key].should be_true
      end

      it 'yields info about the key, when the key was changed' do
        body = MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'bar', 'prevValue' => 'baz', 'index' => 3})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        info = nil
        client.watch('/foo') do |_, _, i|
          info = i
        end
        info[:action].should == :set
        info[:key].should == '/foo/bar'
        info[:value].should == 'bar'
        info[:index].should == 3
        info[:previous_value].should == 'baz'
      end

      it 'yields info about the key, when the key has a TTL' do
        body = MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 3, 'expiration' => '2013-12-11T12:09:08.123+02:00', 'ttl' => 7})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        info = nil
        client.watch('/foo') do |_, _, i|
          info = i
        end
        info[:action].should == :set
        info[:key].should == '/foo/bar'
        info[:value].should == 'bar'
        info[:index].should == 3
        # rounding because of ruby 2.0 time parsing bug @see https://gist.github.com/mindreframer/6746829
        info[:expiration].to_f.round.should == (Time.utc(2013, 12, 11, 10, 9, 8) + 0.123).to_f.round
        info[:ttl].should == 7
      end

      it 'returns the return value of the block' do
        body = MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 3, 'expiration' => '2013-12-11T12:09:08.123+02:00', 'ttl' => 7})
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: body)
        return_value = client.watch('/foo') do |_, k, _|
          k
        end
        return_value.should == '/foo/bar'
      end
    end


    describe '#observe' do
      it 'watches the specified key prefix' do
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: MultiJson.dump({}))
        barrier = Queue.new
        observer = client.observe('/foo') do
          barrier << :ping
          observer.cancel
          observer.join
        end
        barrier.pop
        WebMock.should have_requested(:get, "#{base_uri}/watch/foo").with(query: {})
      end

      it 're-watches the prefix with the (last seen index + 1)  immediately' do
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: MultiJson.dump({'index' => 3}))
        stub_request(:post, "#{base_uri}/watch/foo").with(query: {'index' => 4}).to_return(body: MultiJson.dump({'index' => 4}))
        barrier = Queue.new
        observer = client.observe('/foo') do |_, _, info|
          if info[:index] == 4
            barrier << :ping
            observer.cancel
            observer.join
          end
        end
        barrier.pop
        WebMock.should have_requested(:get, "#{base_uri}/watch/foo").with(query: {})
        WebMock.should have_requested(:post, "#{base_uri}/watch/foo").with(query: {'index' => 4})
      end

      it 'yields the value, key and info to the block given' do
        stub_request(:get, "#{base_uri}/watch/foo").with(query: {}).to_return(body: MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'bar', 'index' => 3, 'newKey' => true}))
        stub_request(:post, "#{base_uri}/watch/foo").with(query: {'index' => 4}).to_return(body: MultiJson.dump({'action' => 'DELETE', 'key' => '/foo/baz', 'value' => 'foo', 'index' => 4}))
        stub_request(:post, "#{base_uri}/watch/foo").with(query: {'index' => 5}).to_return(body: MultiJson.dump({'action' => 'SET', 'key' => '/foo/bar', 'value' => 'hello', 'index' => 5}))
        barrier = Queue.new
        values   = []
        keys     = []
        actions  = []
        new_keys = []
        observer = client.observe('/foo') do |value, key, info|
          values    << value
          keys      << key
          actions   << info[:action]
          new_keys  << info[:new_key]
          if info[:index] == 5
            barrier << :ping
            observer.cancel
            observer.join
          end
        end
        barrier.pop
        values.should   == %w[bar foo hello]
        keys.should     == %w[/foo/bar /foo/baz /foo/bar]
        actions.should  == [:set, :delete, :set]
        new_keys.should == [true, nil, nil]
      end
    end

  end
end
