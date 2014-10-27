# encoding: utf-8
require 'spec_helper'


module Etcd
  describe Node do

    def default_node(opts = {})
      args = {:name => "node1", :etcd => "http://example.com:4001", :raft => "http://example.com:7001"}
      Etcd::Node.new(args.merge(opts))
    end

    describe '#initialize' do
      it "works with all required parameters" do
        default_node({}).should_not == nil
      end

      it "raises if :etcd url is missing" do
        expect {
          default_node({:etcd => nil})
        }.to raise_error(ArgumentError)
      end
    end

    describe '#update_status' do
      it "sets status :running if alive" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.raft)
        node.update_status
        node.status.should == :running
      end

      it "sets status :down if down" do
        node = default_node
        stub_request(:get, node.leader_uri).to_timeout
        node.update_status
        node.status.should == :down
      end

      it "marks leader-flag if leader" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.raft)
        node.update_status
        node.is_leader.should eq(true)
      end

      it "marks leader-flag as :false if leader looses leadership" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.raft)
        node.update_status
        node.is_leader.should eq(true)
        stub_request(:get, node.leader_uri).to_return(body: "bla")
        node.update_status
        node.is_leader.should eq(false)
      end
    end
  end
end
