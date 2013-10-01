module Etcd
  class Http
    def self.client
      @client ||= reset_client!
    end

    def self.reset_client!
      @client = HTTPClient.new(agent_name: "etcd-rb/#{VERSION}")
    end

    def self.request(method, uri, args={})
      # to remove the '?' mark for simple get requests
      args = nil if args == {}
      client.request(method, uri, args)
    end

    def self.request_data(method, uri, args={})
      response = request(method, uri, args)
      if response.status_code == 200
        MultiJson.load(response.body)
      end
    end
  end


  module Requestable
    def request_data(method, uri, args={})
      Etcd::Http.request_data(method, uri, args)
    end

    def request(method, uri, args={})
      Etcd::Http.request(method, uri, args)
    end
  end
end
