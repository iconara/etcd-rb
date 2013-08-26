# encoding: utf-8

require 'time'
require 'thread'
require 'httpclient'
require 'multi_json'


module Etcd
  # A client for `etcd`. Implements all core operations (`get`, `set`, `delete`
  # and `watch`) and features (TTL, atomic test-and-set, listing directories,
  # etc).
  #
  # In addition to the core operations there are a few convenience methods for
  # doing test-and-set (a.k.a. compare-and-swap, atomic update), and continuous
  # watching.
  #
  # @note All methods that take a key or prefix as argument will prepend a slash
  #   to the key if it does not start with slash.
  #
  # @example Basic usage
  #   client = Etcd::Client.new
  #   client.set('/foo/bar', 'baz')
  #   client.get('/foo/bar') # => 'baz'
  #   client.delete('/foo/bar') # => 'baz'
  #
  # @example Make a key expire automatically after 5s
  #   client.set('/foo', 'bar', ttl: 5)
  #
  # @example Atomic updates
  #   client.set('/foo/bar', 'baz')
  #   # ...
  #   if client.update('/foo/bar', 'qux', 'baz')
  #     puts 'Nobody changed our data'
  #   end
  #
  # @example Listing a directory
  #   client.set('/foo/bar', 'baz')
  #   client.set('/foo/qux', 'fizz')
  #   client.get('/foo') # => {'/foo/bar' => 'baz', '/foo/qux' => 'fizz'}
  #
  # @example Getting info for a key
  #   client.set('/foo', 'bar', ttl: 5)
  #   client.info('/foo') # => {:key => '/foo',
  #                       #     :value => '/bar',
  #                       #     :expires => Time.utc(...),
  #                       #     :ttl => 4}
  #
  # @example Observing changes to a key
  #   observer = client.observe('/foo') do |value, key|
  #     # This will be run asynchronously
  #     puts "The key #{key}" changed to #{value}"
  #   end
  #   client.set('/foo/bar', 'baz') # "The key /foo/bar changed to baz" is printed
  #   client.set('/foo/qux', 'fizz') # "The key /foo/qux changed to fizz" is printed
  #   # stop receiving change notifications
  #   observer.cancel
  # 
  class Client
    # Creates a new `etcd` client.
    #
    # You should call {#connect} on the client to properly initialize it. The
    # creation of the client and connection is divided into two parts to avoid
    # doing network connections in the object initialization code. Many times
    # you want to defer things with side-effect until the whole object graph
    # has been created. {#connect} returns self so you can just chain it after
    # the call to {.new}, e.g. `Client.new.connect`.
    #
    # You can specify a seed node to connect to using the `:host` and `:port`
    # options (which default to 127.0.0.1:4001), but once connected the client
    # will prefer to talk to the master in order to avoid unnecessary HTTP
    # requests, and to make sure that get operations find the most recent value.
    #
    # @param [Hash] options
    # @option options [String] :host ('127.0.0.1') The etcd host to connect to
    # @option options [String] :port (4001) The port to connect to
    def initialize(options={})
      @host = options[:host] || '127.0.0.1'
      @port = options[:port] || 4001
      @http_client = HTTPClient.new(agent_name: "etcd-rb/#{VERSION}")
      @http_client.redirect_uri_callback = method(:handle_redirected)
    end

    def connect
      change_leader(leader)
      self
    rescue AllNodesDownError => e
      raise ConnectionError, e.message, e.backtrace
    end

    # Sets the value of a key.
    #
    # Accepts an optional `:ttl` which is the number of seconds that the key
    # should live before being automatically deleted.
    #
    # @param key [String] the key to set
    # @param value [String] the value to set
    # @param options [Hash]
    # @option options [Fixnum] :ttl (nil) an optional time to live (in seconds)
    #   for the key
    # @return [String] The previous value (if any)
    def set(key, value, options={})
      body = {:value => value}
      if ttl = options[:ttl]
        body[:ttl] = ttl
      end
      response = request(:post, uri(key), body: body)
      data = MultiJson.load(response.body)
      data[S_PREV_VALUE]
    end

    # Atomically sets the value for a key if the current value for the key
    # matches the specified expected value.
    #
    # Returns `true` when the operation succeeds, i.e. when the specified
    # expected value matches the current value. Returns `false` otherwise.
    #
    # Accepts an optional `:ttl` which is the number of seconds that the key
    # should live before being automatically deleted.
    #
    # @param key [String] the key to set
    # @param value [String] the value to set
    # @param expected_value [String] the value to compare to the current value
    # @param options [Hash]
    # @option options [Fixnum] :ttl (nil) an optional time to live (in seconds)
    #   for the key
    # @return [true, false] whether or not the operation succeeded
    def update(key, value, expected_value, options={})
      body = {:value => value, :prevValue => expected_value}
      if ttl = options[:ttl]
        body[:ttl] = ttl
      end
      response = request(:post, uri(key), body: body)
      response.status == 200
    end

    # Gets the value or values for a key.
    #
    # If the key represents a directory with direct decendants (e.g. "/foo" for
    # "/foo/bar") a hash of keys and values will be returned.
    #
    # @param key [String] the key or prefix to retrieve
    # @return [String, Hash] the value for the key, or a hash of keys and values
    #   when the key is a prefix.
    def get(key)
      response = request(:get, uri(key))
      if response.status == 200
        data = MultiJson.load(response.body)
        if data.is_a?(Array)
          data.each_with_object({}) do |e, acc|
            acc[e[S_KEY]] = e[S_VALUE]
          end
        else
          data[S_VALUE]
        end
      else
        nil
      end
    end

    # Returns info about a key, such as TTL, expiration and index.
    #
    # For keys with values the returned hash will include `:key`, `:value` and
    # `:index`. Additionally for keys with a TTL set there will be a `:ttl` and
    # `:expiration` (as a UTC `Time`).
    #
    # For keys that represent directories with no direct decendants (e.g. "/foo"
    # for "/foo/bar/baz") the `:dir` key will have the value `true`.
    #
    # For keys that represent directories with direct decendants (e.g. "/foo"
    # for "/foo/bar") a hash of keys and info will be returned.
    #
    # @param key [String] the key or prefix to retrieve
    # @return [Hash] a with info about the key, the exact contents depend on
    #   what kind of key it is.
    def info(key)
      response = request(:get, uri(key))
      if response.status == 200
        data = MultiJson.load(response.body)
        if data.is_a?(Array)
          data.each_with_object({}) do |d, acc|
            info = extract_info(d)
            info.delete(:action)
            acc[info[:key]] = info
          end
        else
          info = extract_info(data)
          info.delete(:action)
          info
        end
      else
        nil
      end
    end

    # Remove a key and its value.
    #
    # The previous value is returned, or `nil` if the key did not exist.
    #
    # @param key [String] the key to remove
    # @return [String] the previous value, if any
    def delete(key)
      response = request(:delete, uri(key))
      if response.status == 200
        data = MultiJson.load(response.body)
        data[S_PREV_VALUE]
      else
        nil
      end
    end

    # Returns true if the specified key exists.
    #
    # This is a convenience method and equivalent to calling {#get} and checking
    # if the value is `nil`.
    #
    # @return [true, false] whether or not the specified key exists
    def exists?(key)
      !!get(key)
    end

    # Watches a key or prefix and calls the given block when with any changes.
    #
    # This method will block until the server replies. There is no way to cancel
    # the call.
    #
    # The parameters to the block are the value, the key and a hash of
    # additional info. The info will contain the `:action` that caused the
    # change (`:set`, `:delete` etc.), the `:key`, the `:value`, the `:index`,
    # `:new_key` with the value `true` when a new key was created below the
    # watched prefix, `:previous_value`, if any, `:ttl` and `:expiration` if
    # applicable.
    #
    # The reason why the block parameters are in the order`value`, `key` instead
    # of `key`, `value` is because you almost always want to get the new value
    # when you watch, but not always the key, and most often not the info. With
    # this order you can leave out the parameters you don't need.
    #
    # @param prefix [String] the key or prefix to watch
    # @param options [Hash]
    # @option options [Fixnum] :index (nil) the index to start watching from
    # @yieldparam [String] value the value of the key that changed
    # @yieldparam [String] key the key that changed
    # @yieldparam [Hash] info the info for the key that changed
    # @return [Object] the result of the given block
    def watch(prefix, options={})
      parameters = {}
      if index = options[:index]
        parameters[:index] = index
      end
      response = request(:get, uri(prefix, S_WATCH), query: parameters)
      data = MultiJson.load(response.body)
      info = extract_info(data)
      yield info[:value], info[:key], info
    end

    # Sets up a continuous watch of a key or prefix.
    #
    # This method works like {#watch} (which is used behind the scenes), but
    # will re-watch the key or prefix after receiving a change notificiation.
    #
    # When re-watching the index of the previous change notification is used,
    # so no subsequent changes will be lost while a change is being processed.
    #
    # Unlike {#watch} this method as asynchronous. The watch handler runs in a
    # separate thread (currently a new thread is created for each invocation,
    # keep this in mind if you need to watch many different keys), and can be
    # cancelled by calling `#cancel` on the returned object.
    #
    # Because of implementation details the watch handler thread will not be
    # stopped directly when you call `#cancel`. The thread will be blocked until
    # the next change notification (which will be ignored). This will have very
    # little effect on performance since the thread will not be runnable. Unless
    # you're creating lots of observers it should not matter. If you want to
    # make sure you wait for the thread to stop you can call `#join` on the
    # returned object.
    #
    # @example Creating and cancelling an observer
    #   observer = client.observe('/foo') do |value|
    #     # do something on changes
    #   end
    #   # ...
    #   observer.cancel
    #
    # @return [#cancel, #join] an observer object which you can call cancel and
    #   join on
    def observe(prefix, &handler)
      Observer.new(self, prefix, handler).tap(&:run)
    end

    # Returns the host and port of the leader of the `etcd` cluster.
    #
    # @return [String] the host and port (e.g. "example.com:4001") of the leader
    def leader
      response = request(:get, leader_uri)
      response.body
    end

    # Returns a list of the machines in the `etcd` cluster.
    #
    # @return [Array<String>] the hosts and ports of the machines in the cluster
    def machines
      response = request(:get, machines_uri)
      response.body.split(S_COMMA)
    end

    private

    S_KEY = 'key'.freeze
    S_KEYS = 'keys'.freeze
    S_VALUE = 'value'.freeze
    S_INDEX = 'index'.freeze
    S_EXPIRATION = 'expiration'.freeze
    S_TTL = 'ttl'.freeze
    S_NEW_KEY = 'newKey'.freeze
    S_DIR = 'dir'.freeze
    S_PREV_VALUE = 'prevValue'.freeze
    S_ACTION = 'action'.freeze
    S_WATCH = 'watch'.freeze
    S_LOCATION = 'location'.freeze

    S_SLASH = '/'.freeze
    S_COMMA = ','.freeze

    def uri(key, action=S_KEYS)
      key = "/#{key}" unless key.start_with?(S_SLASH)
      "http://#{@host}:#{@port}/v1/#{action}#{key}"
    end

    def leader_uri
      @leader_uri ||= "http://#{@host}:#{@port}/leader"
    end

    def machines_uri
      @machines_uri ||= "http://#{@host}:#{@port}/machines"
    end

    def request(method, uri, args={})
      @http_client.request(method, uri, args.merge(follow_redirect: true))
    rescue HTTPClient::TimeoutError => e
      old_leader, old_port = @host, @port
      handle_leader_down
      uri.sub!("#{old_leader}:#{old_port}", "#{@host}:#{@port}")
      retry
    end

    def extract_info(data)
      info = {
        :key => data[S_KEY],
        :value => data[S_VALUE],
        :index => data[S_INDEX],
      }
      expiration_s = data[S_EXPIRATION]
      ttl = data[S_TTL]
      previous_value = data[S_PREV_VALUE]
      action_s = data[S_ACTION]
      info[:expiration] = Time.iso8601(expiration_s) if expiration_s
      info[:ttl] = ttl if ttl
      info[:new_key] = data[S_NEW_KEY] if data.include?(S_NEW_KEY)
      info[:dir] = data[S_DIR] if data.include?(S_DIR)
      info[:previous_value] = previous_value if previous_value
      info[:action] = action_s.downcase.to_sym if action_s
      info
    end

    def handle_redirected(uri, response)
      location = URI.parse(response.header[S_LOCATION][0])
      change_leader(location.host, port: location.port)
      @http_client.default_redirect_uri_callback(uri, response)
    end

    def handle_leader_down
      if @machines && @machines.any?
        @machines = @machines.reject { |m| m == @host }
        change_leader(@machines.shift, flush_cache: false)
      else
        raise AllNodesDownError, 'All known nodes are down'
      end
    end

    def change_leader(new_leader, options={})
      if options[:port]
        @host, @port = new_leader, options[:port]
      else
        @host, port = new_leader.split(':')
        @port = port.to_i
      end
      @leader_uri = nil
      @machines_uri = nil
      if options[:flush_cache] != false
        @machines = machines
      end
    end

    # @private
    class Observer
      def initialize(client, prefix, handler)
        @client = client
        @prefix = prefix
        @handler = handler
      end

      def run
        @running = true
        index = nil
        @thread = Thread.start do
          while @running
            @client.watch(@prefix, index: index) do |value, key, info|
              if @running
                index = info[:index]
                @handler.call(value, key, info)
              end
            end
          end
        end
        self
      end

      def cancel
        @running = false
        self
      end

      def join
        @thread.join
        self
      end
    end
  end
end
