module Rubix
  module Web
    class Controller
      def self.before_action(*methods)
        @before_actions ||= []
        @before_actions.concat(methods)
      end

      def run_before_actions
        self.class.instance_variable_get(:@before_actions)&.each do |method|
          send(method) if respond_to?(method)
        end
      end

      def render(options = {})
        if options[:json]
          [options[:status] || 200, { 'Content-Type' => 'application/json' }, [options[:json].to_json]]
        else
          [200, {}, ['']]
        end
      end

      def params
        @params ||= {}
      end

      def request
        @request
      end

      def response
        @response
      end
    end

    class Router
      def initialize
        @routes = {}
      end

      def get(path, controller, action)
        @routes[[path, 'GET']] = [controller, action]
      end

      def post(path, controller, action)
        @routes[[path, 'POST']] = [controller, action]
      end

      def call(env)
        path = env['PATH_INFO']
        method = env['REQUEST_METHOD']
        route = @routes[[path, method]]
        if route
          controller_class, action = route
          controller = controller_class.new
          controller.instance_variable_set(:@params, parse_params(env))
          controller.run_before_actions
          controller.send(action)
        else
          [404, {}, ['Not Found']]
        end
      end

      private

      def parse_params(env)
        # Simple param parsing
        {}
      end
    end

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      end
    end

    class Server
      def initialize(config, middleware, router)
        @config = config
        @middleware = middleware
        @router = router
      end

      def start
        require 'webrick'
        server = WEBrick::HTTPServer.new(
          Port: @config[:port] || 3000,
          Host: @config[:host] || '0.0.0.0'
        )

        app = build_app

        server.mount_proc '/' do |req, res|
          env = {
            'REQUEST_METHOD' => req.request_method,
            'PATH_INFO' => req.path,
            'QUERY_STRING' => req.query_string || '',
            'CONTENT_TYPE' => req.content_type,
            'CONTENT_LENGTH' => req.content_length,
            'rack.input' => StringIO.new(req.body || ''),
            'rack.url_scheme' => 'http'
          }

          status, headers, body = app.call(env)

          res.status = status
          headers.each do |k, v|
            res[k] = v
          end
          res.body = body.join
        end

        trap('INT') { server.shutdown }
        server.start
      end

      private

      def build_app
        app = @router
        @middleware.reverse.each do |middleware|
          app = middleware.new(app)
        end
        app
      end
    end
  end
end
