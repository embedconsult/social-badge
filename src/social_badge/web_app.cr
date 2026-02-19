require "json"
require "kemal"
require "./timeline_service"
require "./policy_service"

module SocialBadge
  class WebApp
    def initialize(
      @timeline : TimelineService = TimelineService.new,
      @policies : PolicyService = PolicyService.new,
    )
      @message_creation = MessageCreationService.new(@timeline)
    end

    def routes
      get "/health" do |env|
        env.response.content_type = "application/json"
        {status: "ok", service: "social-badge", version: VERSION}.to_json
      end

      get "/api/profile" do |env|
        env.response.content_type = "application/json"
        @timeline.identity.to_json
      end

      get "/api/timeline" do |env|
        env.response.content_type = "application/json"
        limit = env.params.query["limit"]?.try(&.to_i?) || 25
        @timeline.timeline(limit.clamp(1, 100)).to_json
      end

      get "/api/policy/trust" do |env|
        env.response.content_type = "application/json"
        @policies.trust_policy.to_json
      end

      get "/api/policy/input" do |env|
        env.response.content_type = "application/json"
        @policies.input_policy.to_json
      end

      post "/api/messages" do |env|
        env.response.content_type = "application/json"
        message = @message_creation.create(env.request.body)
        env.response.status_code = 201
        message.to_json
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
      end
    end
  end
end
