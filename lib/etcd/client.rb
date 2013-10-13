# encoding: utf-8

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

  # @example Basic usage
  #   seed_uris = ['http://127.0.0.1:4001', 'http://127.0.0.1:4002', 'http://127.0.0.1:4003']
  #   client = Etcd::Client.connect(:uris => seed_uris)
  #   client.set('/foo/bar', 'baz')
  #   client.get('/foo/bar') # => 'baz'
  #   client.delete('/foo/bar') # => 'baz'

  # @example Make a key expire automatically after 5s
  #   client.set('/foo', 'bar', ttl: 5)

  # @example Atomic updates
  #   client.set('/foo/bar', 'baz')
  #   # ...
  #   if client.update('/foo/bar', 'qux', 'baz')
  #     puts 'Nobody changed our data'
  #   end

  # @example Listing a directory
  #   client.set('/foo/bar', 'baz')
  #   client.set('/foo/qux', 'fizz')
  #   client.get('/foo') # => {'/foo/bar' => 'baz', '/foo/qux' => 'fizz'}

  # @example Getting info for a key
  #   client.set('/foo', 'bar', ttl: 5)
  #   client.info('/foo') # => {:key => '/foo',
  #                       #     :value => '/bar',
  #                       #     :expires => Time.utc(...),
  #                       #     :ttl => 4}

  # @example Observing changes to a key
  #   observer = client.observe('/foo') do |value, key|
  #     # This will be run asynchronously
  #     puts "The key #{key}" changed to #{value}"
  #   end
  #   client.set('/foo/bar', 'baz') # "The key /foo/bar changed to baz" is printed
  #   client.set('/foo/qux', 'fizz') # "The key /foo/qux changed to fizz" is printed
  #   # stop receiving change notifications
  #   observer.cancel


  class Client
    include Etcd::Constants
    include Etcd::Requestable
    include Etcd::Loggable

    attr_accessor :cluster
    attr_accessor :leader
    attr_accessor :seed_uris
    attr_accessor :heartbeat_freq
    attr_accessor :observers
    attr_accessor :status # :up/:down


    # @param options [Hash]
    # @option options [Array] :uris (['http://127.0.0.1:4001']) seed uris with etcd cluster nodes
    # @option options [Integer] :heartbeat_freq (0) check-frequency for leader status (in seconds)
    #  Heartbeating will start only for non-zero values
    def initialize(options={})
      @observers      = {}
      @seed_uris      = options[:uris] || ['http://127.0.0.1:4001']
      @heartbeat_freq = options[:heartbeat_freq].to_f
      http_client.redirect_uri_callback = method(:handle_redirected)
    end

    # Create a new client and connect it to the etcd cluster.
    #
    # This method is the preferred way to create a new client, and is the
    # equivalent of `Client.new(options).connect`. See {#initialize} and
    # {#connect} for options and details.
    #
    # @see #initialize
    # @see #connect
    def self.connect(options={})
      self.new(options).connect
    end

    # Connects to the etcd cluster
    #
    # @see #update_cluster
    def connect
      update_cluster
      start_heartbeat_if_needed
      self
    end

    # Creates a Cluster-instance from `@seed_uris`
    # and stores the cluster leader information
    def update_cluster
      logger.debug("update_cluster: enter")
      begin
        @cluster = Etcd::Cluster.init_from_uris(*seed_uris)
        @leader  = @cluster.leader
        @status  = :up
        logger.debug("update_cluster: after success")
        refresh_observers
        @leader
      rescue AllNodesDownError => e
        logger.debug("update_cluster: failed")
      end
    end

    # kinda magic accessor-method:
    # - will reinitialize leader && cluster if needed
    def leader
      @leader ||= cluster && cluster.leader || update_cluster && self.leader
    end

    def leader_uri
      leader && @leader.etcd
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
      body       = {:value => value}
      body[:ttl] = options[:ttl] if options[:ttl]
      data       = request_data(:post, key_uri(key), body: body)
      data[S_PREV_VALUE]
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
      data = request_data(:get, key_uri(key))
      return nil unless data
      if data.is_a?(Array)
        data.each_with_object({}) do |e, acc|
          acc[e[S_KEY]] = e[S_VALUE]
        end
      else
        data[S_VALUE]
      end
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
      body       = {:value => value, :prevValue => expected_value}
      body[:ttl] = options[:ttl] if options[:ttl]
      data       = request_data(:post, key_uri(key), body: body)
      !! data
    end

    # Remove a key and its value.
    #
    # The previous value is returned, or `nil` if the key did not exist.
    #
    # @param key [String] the key to remove
    # @return [String] the previous value, if any
    def delete(key)
      data = request_data(:delete, key_uri(key))
      return nil unless data
      data[S_PREV_VALUE]
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
      data = request_data(:get, uri(key))
      return nil unless data
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
      parameters         = {}
      parameters[:index] = options[:index] if options[:index]
      data               = request_data(:get, watch_uri(prefix), query: parameters)
      info               = extract_info(data)
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
      ob = Observer.new(self, prefix, handler).tap(&:run)
      @observers[prefix] = ob
      ob
    end

    # Initiates heartbeating the leader node in a background thread
    # ensures, that observers are refreshed after leader re-election
    def start_heartbeat_if_needed
      return if @heartbeat_freq == 0
      return if @heartbeat_thread
      @heartbeat_thread = Thread.new do
        while true do
          heartbeat_command
        end
      end
    end


    # Pretty output in development console
    def inspect
      %Q(<Etcd::Client #{seed_uris}>)
    end

    # Only happens on attempted write to a follower node in cluster. Means:
    # - leader changed since last update
    # Solution: just get fresh cluster status
    def handle_redirected(uri, response)
      update_cluster
      http_client.default_redirect_uri_callback(uri, response)
    end

private
    def key_uri(key)
      uri(key, S_KEYS)
    end

    def watch_uri(key)
      uri(key, S_WATCH)
    end

    # :uri and :request_data are the only methods calling :leader method
    # so they both need to handle the case for missing leader in cluster
    def uri(key, action=S_KEYS)
      raise AllNodesDownError unless leader
      key = "/#{key}" unless key.start_with?(S_SLASH)
      "#{leader_uri}/v1/#{action}#{key}"
    end


    def request_data(method, uri, args={})
      logger.debug("request_data:  #{method} - #{uri} #{args.inspect}")
      begin
        super
      rescue Errno::ECONNREFUSED, HTTPClient::TimeoutError => e
        logger.debug("request_data:  re-election handling")
        old_leader_uri = @leader.etcd
        update_cluster
        if @leader
          uri = uri.gsub(old_leader_uri, @leader.etcd)
          retry
        else
          raise AllNodesDownError
        end
      end
    end


    # Re-initiates watches after leader election
    def refresh_observers
      logger.debug("refresh_observers: enter")
      observers.each do |_, observer|
        observer.rerun
      end
    end

    def observers_overview
      observers.map do |_, observer|
        observer.status
      end
    end

    # The command to check leader online status,
    # runs in background and is resilient to failures
    def heartbeat_command
      logger.debug("heartbeat_command: enter ")
      logger.debug(observers_overview.join(", "))
      begin
        if @status == :down
          update_cluster
          @status = :up if leader
        end
        request_data(:get, key_uri("foo"))
      rescue Exception => e
        @status = :down
        logger.debug "heartbeat - #{e.message} #{e.backtrace}"
      end
      sleep heartbeat_freq
    end

    def extract_info(data)
      info = {
        :key   => data[S_KEY],
        :value => data[S_VALUE],
        :index => data[S_INDEX],
      }
      expiration_s          = data[S_EXPIRATION]
      ttl                   = data[S_TTL]
      previous_value        = data[S_PREV_VALUE]
      action_s              = data[S_ACTION]
      info[:expiration]     = Time.iso8601(expiration_s) if expiration_s
      info[:ttl]            = ttl if ttl
      info[:new_key]        = data[S_NEW_KEY] if data.include?(S_NEW_KEY)
      info[:dir]            = data[S_DIR] if data.include?(S_DIR)
      info[:previous_value] = previous_value if previous_value
      info[:action]         = action_s.downcase.to_sym if action_s
      info
    end

  end
end
