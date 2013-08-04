# encoding: utf-8

require 'time'
require 'thread'
require 'httpclient'
require 'multi_json'


module Etcd
  class Client
    def initialize(options={})
      @host = options[:host] || 'localhost'
      @port = options[:port] || 4001
      @http_client = HTTPClient.new(agent_name: "etcd-rb/#{VERSION}")
    end

    def set(key, value, options={})
      body = {:value => value}
      if ttl = options[:ttl]
        body[:ttl] = ttl
      end
      response = @http_client.post(uri(key), body)
      data = MultiJson.load(response.body)
      data[S_PREV_VALUE]
    end

    def update(key, value, previous_value, options={})
      body = {:value => value, :prevValue => previous_value}
      if ttl = options[:ttl]
        body[:ttl] = ttl
      end
      response = @http_client.post(uri(key), body)
      response.status == 200
    end

    def get(key)
      response = @http_client.get(uri(key))
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

    def info(key)
      response = @http_client.get(uri(key))
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

    def delete(key)
      response = @http_client.delete(uri(key))
      if response.status == 200
        data = MultiJson.load(response.body)
        data[S_PREV_VALUE]
      else
        nil
      end
    end

    def exists?(key)
      !get(key).nil?
    end

    def watch(prefix, options={})
      parameters = {}
      if index = options[:index]
        parameters[:index] = index
      end
      response = @http_client.get(uri(prefix, S_WATCH), parameters)
      data = MultiJson.load(response.body)
      info = extract_info(data)
      yield info[:value], info[:key], info
    end

    def observe(prefix, &handler)
      Observer.new(self, prefix, handler).tap(&:run)
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

    S_SLASH = '/'.freeze

    def uri(key, action=S_KEYS)
      key = "/#{key}" unless key.start_with?(S_SLASH)
      "http://#{@host}:#{@port}/v1/#{action}#{key}"
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

    class Observer
      def initialize(client, prefix, handler)
        @client = client
        @prefix = prefix
        @handler = handler
        @stopped_barrier = Queue.new
      end

      def run
        @running = true
        index = nil
        Thread.start do
          begin
            while @running
              @client.watch(@prefix, index: index) do |value, key, info|
                index = info[:index]
                @handler.call(value, key, info)
              end
            end
          ensure
            @stopped_barrier << nil
          end
        end
      end

      def cancel
        @running = false
        nil
      end

      def join
        @stopped_barrier.pop
      end
    end
  end
end
