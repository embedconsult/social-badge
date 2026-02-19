require "json"
require "kemal"
require "./timeline_service"

module SocialBadge
  class WebApp
    def initialize(@timeline : TimelineService = TimelineService.new)
    end

    def routes
      get "/health" do
        {status: "ok", service: "social-badge", version: VERSION}.to_json
      end

      get "/api/profile" do
        @timeline.identity.to_json
      end

      get "/api/timeline" do |env|
        limit = env.params.query["limit"]?.try(&.to_i?) || 25
        @timeline.timeline(limit.clamp(1, 100)).to_json
      end

      post "/api/messages" do |env|
        request_body = env.request.body.try(&.gets_to_end) || "{}"
        payload = CreateMessageRequest.from_json(request_body)
        message = @timeline.post(payload.body)
        env.response.status_code = 201
        message.to_json
      rescue ex : ArgumentError | JSON::ParseException | JSON::SerializableError
        env.response.status_code = 422
        {error: ex.message}.to_json
      end
    end
  end
end
