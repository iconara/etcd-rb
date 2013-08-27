# encoding: utf-8

require 'spec_helper'
require 'open-uri'


describe 'A etcd client' do
  let :client do
    Etcd::Client.new(host: host, port: port).connect
  end

  let :host do
    ENV['ETCD_HOST']
  end

  let :port do
    ENV['ETCD_PORT'].to_i
  end

  let :prefix do
    "/etcd-rb/#{rand(234234)}"
  end

  let :key do
    "#{prefix}/hello"
  end

  before do
    WebMock.disable!
  end

  before do
    begin
      open("http://#{host}:#{port}/v1/leader").read
    rescue Errno::ECONNREFUSED
      fail('etcd not running, start it with `./spec/resources/etcd-cluster start`')
    end
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
    new_value = client.watch(key) { |value| value }
    new_value.should == 'baz'
  end

  it 'conditionally sets the value for a key' do
    client.set(key, 'bar')
    client.update(key, 'qux', 'baz').should be_false
    client.update(key, 'qux', 'bar').should be_true
  end
end