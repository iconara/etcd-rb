# encoding: utf-8
require 'spec_helper'

module Etcd
  describe Node do

    let :node_data do
      [
       {"id" => "14306b09b8d69fc4","name" => "node1","peerURLs"=> ["http://127.0.0.1:7001"],"clientURLs" => ["http://127.0.0.1:4001"]},
       {"id" => "d2356cd527a56a4","name" => "node2","peerURLs" => ["http://127.0.0.1:7002"],"clientURLs" => ["http://127.0.0.1:4002"]}
      ]
    end

    def default_node(opts = {})
      data = Etcd::Node.parse_node_data(node_data[0])
      Etcd::Node.new(data.merge(opts))
    end

    describe '#initialize' do
      it "works with all required parameters" do
        default_node({}).should_not be_nil
      end

      it "raises if :client_urls is missing" do
        expect {
          default_node({:client_urls => nil})
        }.to raise_error(ArgumentError)
      end

      it "raises if :id is missing" do
        expect {
          default_node({:id => nil})
        }.to raise_error(ArgumentError)
      end
    end

    describe '#update_status' do
      it "sets status :running if alive" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.to_json)
        node.update_status
        node.status.should eq(:running)
      end

      it "sets status :down if down" do
        node = default_node
        stub_request(:get, node.leader_uri).to_timeout
        node.update_status
        node.status.should eq(:down)
      end

      it "marks leader-flag if leader" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.to_json)
        node.update_status
        node.is_leader.should eq(true)
      end

      it "marks leader-flag as :false if leader looses leadership" do
        node = default_node
        stub_request(:get, node.leader_uri).to_return(body: node.to_json)
        node.update_status
        node.is_leader.should eq(true)
        stub_request(:get, node.leader_uri).to_return(body: node_data[1].to_json)
        node.update_status
        node.is_leader.should eq(false)
      end
    end
  end
end
