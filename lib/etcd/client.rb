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
      data['prevValue']
    end

    def get(key)
      response = @http_client.get(uri(key))
      if response.status == 200
        data = MultiJson.load(response.body)
        if data.is_a?(Array)
          data.each_with_object({}) do |e, acc|
            acc[e['key']] = e['value']
          end
        else
          data['value']
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
        data['prevValue']
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
      response = @http_client.get(uri(prefix, 'watch'), parameters)
      data = MultiJson.load(response.body)
      info = extract_info(data)
      yield info[:value], info[:key], info
    end

    private

    def uri(key, action='keys')
      key = "/#{key}" unless key.start_with?('/')
      "http://#{@host}:#{@port}/v1/#{action}#{key}"
    end

    def extract_info(data)
      info = {
        :key => data['key'],
        :value => data['value'],
        :index => data['index'],
      }
      info[:expiration] = Time.iso8601(data['expiration']) if data['expiration']
      info[:ttl] = data['ttl'] if data['ttl']
      info[:new_key] = data['newKey'] if data['newKey']
      info[:previous_value] = data['prevValue'] if data['prevValue']
      info[:action] = data['action'].downcase.to_sym if data['action']
      info
    end
  end
end
