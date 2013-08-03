# encoding: utf-8

require 'spec_helper'


module Etcd
  describe Client do
    let :client do
      described_class.new(host: host, port: port)
    end

    let :host do
      'example.com'
    end

    let :port do
      rand(2**16)
    end

    let :base_uri do
      "http://#{host}:#{port}/v1"
    end

    describe '#get' do
      before do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'value' => 'bar'}))
      end

      it 'sends a GET request to retrieve the value' do
        client.get('foo')
        WebMock.should have_requested(:get, "#{base_uri}/keys/foo")
      end

      it 'parses the response and returns the value' do
        client.get('foo').should == 'bar'
      end

      it 'returns nil if when the value does not exist' do
        stub_request(:get, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.get('foo').should be_nil
      end

      context 'when listing a prefix' do
        it 'returns a hash of keys and their values' do
          values = [
            {'key' => '/foo/bar', 'value' => 'bar'},
            {'key' => '/foo/baz', 'value' => 'baz'},
          ]
          stub_request(:get, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump(values))
          client.get('foo').should eql({'/foo/bar' => 'bar', '/foo/baz' => 'baz'})
        end
      end
    end

    describe '#set' do
      before do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a POST request to set the value' do
        client.set('foo', 'bar')
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with { |rq| rq.body == 'value=bar' }
      end

      it 'parses the response and returns the previous value' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevValue' => 'baz'}))
        client.set('foo', 'bar').should == 'baz'
      end

      it 'returns nil when there is no previous value' do
        stub_request(:post, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
        client.set('foo', 'bar').should be_nil
      end

      it 'sets a TTL when the :ttl option is given' do
        client.set('foo', 'bar', ttl: 3)
        WebMock.should have_requested(:post, "#{base_uri}/keys/foo").with { |rq| rq.body == 'value=bar&ttl=3' }
      end
    end

    describe '#delete' do
      before do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({}))
      end

      it 'sends a DELETE request to remove the value' do
        client.delete('foo')
        WebMock.should have_requested(:delete, "#{base_uri}/keys/foo")
      end

      it 'returns the previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(body: MultiJson.dump({'prevValue' => 'bar'}))
        client.delete('foo').should == 'bar'
      end

      it 'returns nil when there is no previous value' do
        stub_request(:delete, "#{base_uri}/keys/foo").to_return(status: 404, body: 'Not found')
        client.delete('foo').should be_nil
      end
    end
  end
end