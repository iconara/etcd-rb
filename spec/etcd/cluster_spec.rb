require 'spec_helper'


module Etcd
  describe Cluster do

    include ClusterHelper

    let :cluster_uri do
      "http://127.0.0.1:4001"
    end

    describe :class_methods do
      describe '#cluster_status' do
        it "returns parsed data" do
          with_stubbed_status(cluster_uri) do
            res = Etcd::Cluster.cluster_status(cluster_uri)
            res[0][:name].should eq("node1")
          end
        end
      end

      describe '#nodes_from_uri' do
        it "returns node instances created from uri" do
          with_stubbed_status(cluster_uri) do
            nodes = Etcd::Cluster.nodes_from_uri(cluster_uri)
            nodes.size.should eq(3)
            nodes.first.class.should eq(Etcd::Node)
          end
        end

        it "but those instances have no real status yet" do
          with_stubbed_status(cluster_uri) do
            nodes = Etcd::Cluster.nodes_from_uri(cluster_uri)
            nodes.size.should eq(3)
            nodes.first.status == :unknown
          end
        end
      end

      describe '#init_from_uris', "- preferred way to initialize cluster" do
        describe "in healthy cluster" do
          it "has all nodes at status :running" do
            with_stubbed_status(cluster_uri) do
              with_stubbed_leaders(healthy_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(cluster_uri)
                puts "nodes: #{cluster}"
                nodes = cluster.nodes
                nodes.size.should eq(3)
                nodes.map{|x| x.status}.uniq.should eq([:running])
              end
            end
          end

          it "has one leader node" do
            with_stubbed_status(cluster_uri) do
              with_stubbed_leaders(healthy_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(cluster_uri)
                leader  = cluster.leader
                expect(leader.client_urls.first).to eq(cluster_uri)
              end
            end
          end
        end


        describe "in un-healthy cluster" do
          it "has some  nodes at status :down" do
            with_stubbed_status(cluster_uri) do
              with_stubbed_leaders(one_down_cluster_config) do
                cluster = Etcd::Cluster.init_from_uris(cluster_uri)
                nodes = cluster.nodes
                nodes.size.should eq(3)
                nodes.map{|x| x.status}.uniq.should eq([:running, :down])
              end
            end
          end
        end
      end
    end

    describe :instance_methods do
      describe '#new' do
        it "will not request any info on initialization" do
          cluster = Etcd::Cluster.new(cluster_uri)
          WebMock.should_not have_requested(:get, "http://127.0.0.1:4001/v2/members/")
        end
      end

      describe '#nodes' do
        it "will update nodes info on first nodes access" do
          with_stubbed_status(cluster_uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(cluster_uri)
              nodes   = cluster.nodes
              nodes.size.should eq(3)
            end
          end
        end

        it "caches result on further queries" do
          with_stubbed_status(cluster_uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(cluster_uri)
              nodes   = cluster.nodes
              nodes.map{|x| x.status}.uniq.should eq([:running])
              with_stubbed_leaders(one_down_cluster_config) do
                nodes   = cluster.nodes
                nodes.map{|x| x.status}.uniq.should_not == [:running, :down]
                # now update for real
                nodes   = cluster.update_status
                nodes.map{|x| x.status}.uniq.should eq([:running, :down])
              end
            end
          end
        end

      end

      describe '#update_status' do
        it "will re-update node stati from etcd" do
          with_stubbed_status(cluster_uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(cluster_uri)
              nodes   = cluster.update_status
              nodes.size.should eq(3)
              nodes.map{|x| x.status}.uniq.should eq([:running])
              with_stubbed_leaders(one_down_cluster_config) do
                nodes   = cluster.update_status
                nodes.map{|x| x.status}.uniq.should eq([:running, :down])
              end
            end
          end
        end
      end

      describe '#leader' do

        it "returns the leader node from nodes" do
          with_stubbed_status(cluster_uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(cluster_uri)
              leader = cluster.leader
              expect(leader.client_urls.first).to eq(cluster_uri)
              expect(leader.is_leader).to eq(true)
            end
          end
        end

        it "re-sets leader after every update_status" do
          with_stubbed_status(cluster_uri) do
            with_stubbed_leaders(healthy_cluster_config) do
              cluster = Etcd::Cluster.new(cluster_uri)
              expect(cluster.leader.client_urls.first).to eq(cluster_uri)
              with_stubbed_leaders(healthy_cluster_changed_leader_config) do
                nodes = cluster.update_status
                expect(cluster.leader.client_urls.first).to eq("http://127.0.0.1:4002")
              end
            end
          end
        end

      end
    end
  end
end
