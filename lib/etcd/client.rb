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
      @http_client = HTTPClient.new
    end

    def set(key, value, options={})
      body = {:value => value}
      body[:ttl] = options[:ttl] if options[:ttl]
      response = @http_client.post(uri(key), body)
      data = MultiJson.load(response.body)
      data[S_PREV_VALUE]
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
        info = extract_info(data)
        info.delete(:action)
        info
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
      parameters[:index] = options[:index] if options[:index]
      response = @http_client.get(uri(prefix, S_WATCH), parameters)
      data = MultiJson.load(response.body)
      info = extract_info(data)
      yield info[:value], info[:key], info
    end

    private

    S_KEY = 'key'.freeze
    S_KEYS = 'keys'.freeze
    S_VALUE = 'value'.freeze
    S_INDEX = 'index'.freeze
    S_EXPIRATION = 'expiration'.freeze
    S_TTL = 'ttl'.freeze
    S_NEW_KEY = 'newKey'.freeze
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
      info[:expiration] = Time.iso8601(data[S_EXPIRATION]) if data[S_EXPIRATION]
      info[:ttl] = data[S_TTL] if data[S_TTL]
      info[:new_key] = data[S_NEW_KEY] if data[S_NEW_KEY]
      info[:previous_value] = data[S_PREV_VALUE] if data[S_PREV_VALUE]
      info[:action] = data[S_ACTION].downcase.to_sym if data[S_ACTION]
      info
    end
  end
end
