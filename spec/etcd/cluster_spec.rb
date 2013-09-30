require 'spec_helper'


module Etcd
  describe Cluster do

    include ClusterHelper

    describe :class_methods do
      describe '#cluster_status' do
        it "returns parsed data" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            res = Etcd::Cluster.cluster_status(uri)
            res[0][:name].should == "node1"
          end
        end
      end

      describe '#parse_cluster_status' do
        it "works with correct parsed json" do
          res = Etcd::Cluster.parse_cluster_status(status_data)
          res[0].should == {
            :name => "node1",
            :raft => "http://127.0.0.1:7001",
            :etcd => "http://127.0.0.1:4001",
          }
        end
      end

      describe '#nodes_from_uri' do
        it "returns node instances created from uri" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            nodes = Etcd::Cluster.nodes_from_uri(uri)
            nodes.size.should == 3
            nodes.first.class.should == Etcd::Node
          end
        end

        it "but those instances have no real status yet" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            nodes = Etcd::Cluster.nodes_from_uri(uri)
            nodes.size.should == 3
            nodes.first.status == :unknown
          end
        end
      end

      describe '#init_from_uris', "- preferred way to initialize cluster" do
        describe "in healthy cluster" do
          it "has all nodes at status :running" do
            uri = "http://127.0.0.1:4001"
            with_stubbed_status(uri) do
              with_stubbed_leaders(healthy_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(uri)
                nodes = cluster.nodes
                nodes.size.should == 3
                nodes.map{|x| x.status}.uniq.should == [:running]
              end
            end
          end

          it "has one leader node" do
            uri = "http://127.0.0.1:4001"
            with_stubbed_status(uri) do
              with_stubbed_leaders(healthy_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(uri)
                leader  = cluster.leader
                leader.etcd.should == uri
              end
            end
          end
        end


        describe "in un-healthy cluster" do
          it "has some  nodes at status :down" do
            uri = "http://127.0.0.1:4001"
            with_stubbed_status(uri) do
              with_stubbed_leaders(one_down_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(uri)
                nodes = cluster.nodes
                nodes.size.should == 3
                nodes.map{|x| x.status}.uniq.should == [:running, :down]
              end
            end
          end
        end
      end
    end

    describe :instance_methods do
      describe '#new' do
        it "will not request any info on initilization" do
          uri = "http://127.0.0.1:4001"
          cluster = Etcd::Cluster.new(uri)
          WebMock.should_not have_requested(:get, "http://127.0.0.1:4001/v1/keys/_etcd/machines/?")
        end
      end

      describe '#nodes' do
        it "will update nodes info on first nodes access" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(uri)
              nodes   = cluster.nodes
              nodes.size.should == 3
            end
          end
        end

        it "caches result on further queries" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(uri)
              nodes   = cluster.nodes
              nodes.map{|x| x.status}.uniq.should == [:running]
              with_stubbed_leaders(one_down_cluster_config) do
                nodes   = cluster.nodes
                nodes.map{|x| x.status}.uniq.should_not == [:running, :down]
                # now update for real
                nodes   = cluster.update_status
                nodes.map{|x| x.status}.uniq.should == [:running, :down]
              end
            end
          end
        end

      end

      describe '#update_status' do
        it "will re-update node stati from etcd" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(uri)
              nodes   = cluster.update_status
              nodes.size.should == 3
              nodes.map{|x| x.status}.uniq.should == [:running]
              with_stubbed_leaders(one_down_cluster_config) do
                nodes   = cluster.update_status
                nodes.map{|x| x.status}.uniq.should == [:running, :down]
              end
            end
          end
        end
      end

      describe '#leader' do

        it "returns the leader node from nodes" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(uri)
              leader = cluster.leader
              leader.etcd.should == "http://127.0.0.1:4001"
              leader.is_leader.should be_true
            end
          end
        end

        it "re-sets leader after every update_status" do
          uri = "http://127.0.0.1:4001"
          with_stubbed_status(uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(uri)
              cluster.leader.etcd.should == "http://127.0.0.1:4001"
              with_stubbed_leaders(healthy_cluster_changed_leader_config) do
                nodes   = cluster.update_status
                cluster.leader.etcd.should == "http://127.0.0.1:4002"
              end
            end
          end
        end

      end
    end
  end
end
