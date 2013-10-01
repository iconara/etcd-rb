module Etcd
  module Requestable
    def http_client
      @http_client ||= reset_http_client!
    end

    def reset_http_client!
      @http_client = HTTPClient.new(agent_name: "etcd-rb/#{VERSION}")
    end

    def request(method, uri, args={})
      # to remove the '?' mark for simple get requests
      args = nil if args == {}
      http_client.request(method, uri, args)
    end

    def request_data(method, uri, args={})
      response = request(method, uri, args)
      if response.status_code == 200
        MultiJson.load(response.body)
      end
    end
  end
end
