# Ruby [etcd](https://github.com/coreos/etcd) driver

[![Build Status](https://travis-ci.org/iconara/etcd-rb.png?branch=master)](https://travis-ci.org/iconara/etcd-rb)
[![Coverage Status](https://coveralls.io/repos/iconara/etcd-rb/badge.png?branch=master)](https://coveralls.io/r/iconara/etcd-rb)

# Requirements

  - A modern Ruby, compatible with 1.9.3 or later. Continously tested with MRI 1.9.3, 2.0.0 and JRuby 1.7.x.
  - Linux/OSX OS
  - to have a local Etcd binary, run
    - `$ sh/install-etcd.sh`

# Installation

    gem install etcd-rb

# Quick start

```ruby
require 'etcd'

client = Etcd::Client.connect(uris: 'http://localhost:4001')
client.connect
client.set('/foo', 'bar')
client.get('/foo')
```

See the full [API documentation](http://rubydoc.info/github/iconara/etcd-rb/master/frames) for more. All core features are supported, including test-and-set, TTL, watches -- as well as a few convenience features like continuous watching.


# Development
    $ git clone https://github.com/iconara/etcd-rb.git
    $ cd etcd-rb
    # will compile the etcd binary in the tmp folder to use for testing
    $ sh/install-etcd.sh
    $ bundle install
    # make your changes
    $ sh/test


# Development helpers
    # console for quick REPL testing
    $ sh/c

    # start/stop Etcd cluster
    $ sh/cluster <start/stop/reset>

    # install Etcd binary to tmp folder
    $ sh/install-etcd.sh

    # run tests
    $ sh/test


# Playing in shell
    # load console with etcd-rb code
    $ sh/c
    > ClusterController.start_cluster
    > seed_uris = ["http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003"]
    > client = Etcd::Client.connect(:uris => seed_uris)


# Features

### Continuous watches: observers

Most of the time when you use watches with etcd you want to immediately re-watch the key when you get a change notification. The `Client#observe` method handles this for you, including re-watching with the last seen index, so that you don't miss any updates.

### Automatic leader detection

All writes go to the leader-node. When the leader is re-elected, next request triggers a redirect and re-evaluation for
the cluster status on the client side. This happens transparently to you. [Example](#example-observers)

### Automatic failover & retry

If a request fails, client will try to get cluster configuration from all given seed URIs until first valid response. Then the original request will be retried. This also happens transparently to you.

Watches are a special case, since they use long polling, they will break when the leader goes down. After a failover observers reestablish their watches with the new leader. Again - this happens transparently to you :) [Example](#example-automatic-failover)


### Heartbeating

To ensure that you have the most up-to-date cluster status and your observers are registered against the current leader node, initiate the client with `:heartbeat_freq  (in seconds) parameter. This will start a background thread, that will periodially check the leader status, which in case of leader re-election will trigger the failover. [Example](#example-heartbeating)


### Example: Automatic Failover

```ruby
# start with
# $ sh/c to have ClusterController available :)
seed_uris = ["http://127.0.0.1:4001", "http://127.0.0.1:4002", "http://127.0.0.1:4003"]
client = Etcd::Client.connect(:uris => seed_uris)


## set some values
client.set("foo", "bar")
client.get("foo") # => bar
client.get("does-not-exist") # => nil

## kill leader node
ClusterController.kill_node(client.cluster.leader.name)

## client still trucking on
client.get("foo") # => bar

## we have visibility into cluster status
puts client.cluster.nodes.map(&:status) # => [:running, :down, :running]

# will leave only one process running by killing the next leader node
ClusterController.kill_node(client.cluster.leader.name)

# but since we have no leader with one process, all requests will fail
client.get("foo") # raises AllNodesDownError error

puts client.cluster.nodes.map(&:status) # => [:running, :down, :down]
client.cluster.leader # => nil

## now start up the cluster in another terminal by executing
ClusterController.start_cluster

## client works again
client.get("foo") # => bar

```


### Example: Observers

```ruby
$ sh/c
# ensure we have a cluster with 3 nodes
ClusterController.start_cluster
# test_client method is only sugar for local development
client = Etcd::Client.test_client

# your block can get value, key and info of the change, that you are observing
client.observe('/foo') do |v,k,info|
  puts "v #{v}, k: #{k}, info: #{info}"
end

# this will trigger the observer
client.set("foo", "bar")
# let's kill the leader of the cluster to demonstrate the re-watching feature
ClusterController.kill_node(client.cluster.leader.name)
# still triggering the observer!
client.set("foo", "bar")
```


### Example: Heartbeating

```ruby
$ sh/c
# ensure we have a cluster with 3 nodes
ClusterController.start_cluster
client = Etcd::Client.test_client(:heartbeat_freq => 5)

# your block can get value, key and info of the change, that you are observing
client.observe('/foo') do |v,k,info|
  puts "v #{v}, k: #{k}, info: #{info}"
end

### START A NEW console with $ `sh/c` helper
client = Etcd::Client.test_client
# this will trigger the observer in the first console
client.set("foo", "bar")
# let's kill the leader of the cluster to demonstrate re-watching && heartbeating for all active clients
ClusterController.kill_node(client.cluster.leader.name)
# still triggering the observer in the first console
# you might loose some changes in the 5-seconds hearbeating window... You should be aware of that.
client.set("foo", "bar")
```



# Changelog & versioning

Check out the [releases on GitHub](https://github.com/iconara/etcd-rb/releases). Version numbering follows the [semantic versioning](http://semver.org/) scheme.


# How to contribute


Fork the repository, make your changes in a topic branch that branches off from the right place in the history (HEAD isn't necessarily always right), make your changes and finally submit a pull request.

Follow the style of the existing code, make sure that existing tests pass, and that everything new has good test coverage. Put some effort into writing clear and concise commit messages, and write a good pull request description.

It takes time to understand other people's code, and even more time to understand a patch, so do as much as you can to make the maintainers' work easier. Be prepared for rejection, many times a feature is already planned, or the proposed design would be in the way of other planned features, or the maintainers' just feel that it will be faster to implement the features themselves than to try to integrate your patch.

Feel free to open a pull request before the feature is finished, that way you can have a conversation with the maintainers' during the development, and you can make adjustments to the design as you go along instead of having your whole feature rejected because of reasons such as those above. If you do, please make it clear that the pull request is a work in progress, or a request for comment.

Always remember that the maintainers' work on this project in their free time and that they don't work for you, or for your benefit. They have no obligation to do what you think is right -- but if you're nice they might anyway.

# Copyright

Copyright 2013 Theo Hultberg/Iconara

_Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License You may obtain a copy of the License at_

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

_Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License._