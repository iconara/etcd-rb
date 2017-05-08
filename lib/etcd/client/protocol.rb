# Implements the etcd V2 client API
#
# Sample API requests/responses
# $ curl -L http://127.0.0.1:4001/v2/keys
# {"action":"get","node":{"dir":true,"nodes":[{"key":"/foo","value":"bar","modifiedIndex":22,"createdIndex":22}]}}
#
# $ curl -L http://127.0.0.1:4001/v2/keys/foo
# {"action":"get","node":{"key":"/foo","value":"bar","modifiedIndex":22,"createdIndex":22}}

module Etcd
  class Client

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
      data       = request_data(:PUT, key_uri(key), body: body)
      data[S_PREV_NODE][S_VALUE] if data && data[S_PREV_NODE]
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
      if nodes = data[S_NODE][S_NODES]
        nodes.each_with_object({}) do |node, acc|
          acc[node[S_KEY]] = node[S_VALUE]
        end
      else
        data[S_NODE][S_VALUE]
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
      data       = request_data(:put, key_uri(key), body: body)
      !! data
    end

    # Remove a key and its value.
    #
    # The previous value is returned, or `nil` if the key did not exist.
    #
    # @param key [String] the key to remove
    # @return [String] the previous value, if any
    def delete(key, args={})
      data = request_data(:delete, key_uri(key), args)
      return nil unless data
      data[S_PREV_NODE][S_VALUE]
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
      if nodes = data[S_NODE][S_NODES]
        nodes.each_with_object({}) do |d, acc|
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
      options.merge!(wait: 'true')
      options.delete(:index) if options.has_key?(:index) && options[:index].nil?
      data = request_data(:get, watch_uri(prefix), query: options)
      info = extract_info(data)
      yield info[:value], info[:key], info
    end


    def key_uri(key)
      uri(key, S_KEYS)
    end

    def watch_uri(key)
      uri(key, S_KEYS)
    end

private

    def extract_info(data)
      if data[S_NODE]
        node = data[S_NODE]
      else
        node = data
      end
      return {} unless node
      info = {
        :key   => node[S_KEY],
        :value => node[S_VALUE],
        :index => node[S_INDEX],
      }
      expiration_s          = node[S_EXPIRATION]
      ttl                   = node[S_TTL]
      action_s              = data[S_ACTION]
      previous_node         = data[S_PREV_NODE]
      info[:expiration]     = Time.iso8601(expiration_s) if expiration_s
      info[:ttl]            = ttl if ttl
      info[:dir]            = node[S_DIR] if node.include?(S_DIR)
      info[:previous_value] = previous_node[S_VALUE] if previous_node
      info[:action]         = action_s.downcase.to_sym if action_s
      info[:new_key]        = !data[S_PREV_NODE]
      info
    end

  end
end
