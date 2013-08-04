# Ruby [etcd](https://github.com/coreos/etcd) driver

[![Build Status](https://travis-ci.org/iconara/etcd-rb.png?branch=master)](https://travis-ci.org/iconara/etcd-rb)
[![Coverage Status](https://coveralls.io/repos/iconara/etcd-rb/badge.png?branch=master)](https://coveralls.io/r/iconara/etcd-rb)

# Requirements

A modern Ruby, compatible with 1.9.3 or later. Continously tested with MRI 1.9.3, 2.0.0 and JRuby 1.7.x.

# Installation

    gem install etcd-rb --prerelease

# Quick start

```ruby
require 'etcd'

client = Etcd::Client.new
client.set('/foo', 'bar')
client.get('/foo')
```

See the full [API documentation](http://rubydoc.info/gems/etcd-rb/frames) for more. All core features are supported, including test-and-set, TTL, watches -- as well as a few convenience features like continuous watching.

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