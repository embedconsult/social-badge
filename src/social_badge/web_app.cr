require "json"
require "kemal"
require "./timeline_service"
require "./message_creation_service"
require "./policy_service"
require "./peer_relay_service"
require "./peer_transport_service"

module SocialBadge
  class WebApp
    def initialize(
      @timeline : TimelineService = TimelineService.new,
      @policies : PolicyService = PolicyService.new,
      @peer_transport : PeerTransportService = PeerTransportService.new(@timeline),
    )
      @message_creation = MessageCreationService.new(@timeline)
      @peer_relay = PeerRelayService.new(@peer_transport)
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

      post "/api/messages" do |env|
        env.response.content_type = "application/json"
        message = @message_creation.create(env.request.body)
        env.response.status_code = 201
        message.to_json
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
      end

      get "/api/peer/outbound_queue" do |env|
        env.response.content_type = "application/json"
        limit = env.params.query["limit"]?.try(&.to_i?) || 25
        @peer_transport.queue(limit.clamp(1, 100)).to_json
      end

      post "/api/peer/relay" do |env|
        env.response.content_type = "application/json"
        relay_job = @peer_relay.enqueue(env.request.body)
        env.response.status_code = 202
        relay_job.to_json
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
      rescue ex : KeyError
        env.response.status_code = 404
        {error: "Unknown message id"}.to_json
      end

      post "/api/peer/inbox" do |env|
        env.response.content_type = "application/json"
        message = @peer_relay.receive(env.request.body)
        env.response.status_code = 202
        if message
          {accepted: true, duplicate: false, message_id: message.id}.to_json
        else
          {accepted: true, duplicate: true}.to_json
        end
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
      end

      post "/api/peer/outbound_queue/:id/failure" do |env|
        env.response.content_type = "application/json"
        relay_job = @peer_transport.mark_failure(env.params.url["id"])
        relay_job.to_json
      rescue ex : KeyError
        env.response.status_code = 404
        {error: "Unknown relay job id"}.to_json
      end

      post "/api/peer/outbound_queue/:id/delivered" do |env|
        env.response.content_type = "application/json"
        relay_job = @peer_transport.mark_delivered(env.params.url["id"])
        relay_job.to_json
      rescue ex : KeyError
        env.response.status_code = 404
        {error: "Unknown relay job id"}.to_json
      end
    end
  end
end
