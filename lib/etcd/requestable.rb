module Etcd
  module Requestable
    include Etcd::Loggable
    def http_client
      @http_client ||= reset_http_client!
    end

    def reset_http_client!
      @http_client = HTTPClient.new(agent_name: "etcd-rb/#{VERSION}")
    end

    def request(method, uri, args={})
      logger.debug("request - #{method} #{uri} #{args.inspect}")
      http_client.request(method, uri, args.merge(follow_redirect: true))
    end

    def request_data(method, uri, args={})
      response = request(method, uri, args)
      if response.status_code == 200
        MultiJson.load(response.body)
      end
    end
  end
end
