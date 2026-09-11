# SPDX-License-Identifier: Apache-2.0
# Native Rails extension point: evaluate the effective method after Rack interprets
# HTML form _method fields, preserving authenticated profile PUT/PATCH/DELETE.
module HelmForge
  class ClosedSelfRegistration
    def initialize(app)
      @app = app
    end

    def call(env)
      path = Rack::Utils.clean_path_info(Rack::Utils.unescape_path(env.fetch('PATH_INFO', '')))
      if env['REQUEST_METHOD'] == 'POST' && path.match?(%r{\A/users(?:\.[^/]*)?/?\z})
        body = '{"error":"self_registration_disabled"}'
        return [403, { 'content-type' => 'application/json', 'content-length' => body.bytesize.to_s }, [body]]
      end
      @app.call(env)
    end
  end
end

Rails.application.config.middleware.insert_after Rack::MethodOverride, HelmForge::ClosedSelfRegistration
