require "json"
require "kemal"
require "./timeline_service"
require "./message_creation_service"
require "./policy_service"
require "./authoring_page_service"
require "./typst_preview_service"
require "./peer_relay_service"
require "./peer_transport_service"
require "./hardware_trial_service"
require "./persistence_service"
require "./activitypub_config"
require "./activitypub_actor_service"
require "./activitypub_inbox_service"
require "./activitypub_outbox_service"
require "./webfinger_service"
require "./http_signature_service"

module SocialBadge
  class WebApp
    def initialize(
      timeline : TimelineService? = nil,
      policies : PolicyService = PolicyService.new,
      peer_transport : PeerTransportService? = nil,
    )
      @persistence = PersistenceService.new
      @timeline = timeline || TimelineService.new(@persistence)
      @policies = policies
      @peer_transport = peer_transport || PeerTransportService.new(@timeline, persistence: @persistence)
      @message_creation = MessageCreationService.new(@timeline)
      @authoring_page = AuthoringPageService.new
      @typst_preview = TypstPreviewService.new
      @peer_relay = PeerRelayService.new(@peer_transport)
      @hardware_trials = HardwareTrialService.new
      @ap_config = ActivityPubConfig.new
      @webfinger = WebFingerService.new(@ap_config)
      @ap_actor = ActivityPubActorService.new(@ap_config)
      @ap_outbox = ActivityPubOutboxService.new(@timeline, @ap_config)
      @ap_inbox = ActivityPubInboxService.new(@timeline)
      @signature = HttpSignatureService.new(
        allow_unsigned: @ap_config.allow_unsigned,
        skip_verify: @ap_config.skip_signature_verify,
      )

      if @typst_preview.startup_status.available
        STDERR.puts "[social-badge] Typst preview enabled: #{@typst_preview.startup_status.detail}"
      else
        STDERR.puts "[social-badge] Typst preview disabled: #{@typst_preview.startup_status.detail}"
      end
    end

    def routes
      get "/" do |env|
        env.response.content_type = "text/html; charset=utf-8"
        @authoring_page.render(@timeline.identity)
      end

      get "/health" do |env|
        env.response.content_type = "application/json"
        {
          status:                  "ok",
          service:                 "social-badge",
          version:                 VERSION,
          typst_preview_available: @typst_preview.startup_status.available,
          typst_preview_detail:    @typst_preview.startup_status.detail,
        }.to_json
      end

      get "/.well-known/webfinger" do |env|
        env.response.content_type = "application/jrd+json"
        resource = env.params.query["resource"]?
        raise ArgumentError.new("Missing resource") unless resource
        @webfinger.lookup(resource).to_json
      rescue ex : ArgumentError
        env.response.status_code = 404
        {error: ex.message}.to_json
      end

      get "/users/:name" do |env|
        env.response.content_type = "application/activity+json"
        @ap_actor.actor_for(env.params.url["name"]).to_json
      rescue ex : ArgumentError
        env.response.status_code = 404
        {error: ex.message}.to_json
      end

      get "/users/:name/outbox" do |env|
        env.response.content_type = "application/activity+json"
        limit = env.params.query["limit"]?.try(&.to_i?) || 25
        @ap_outbox.outbox_for(env.params.url["name"], limit).to_json
      rescue ex : ArgumentError
        env.response.status_code = 404
        {error: ex.message}.to_json
      end

      post "/users/:name/inbox" do |env|
        env.response.content_type = "application/json"
        verification = @signature.verify(env.request)
        unless verification.ok
          env.response.status_code = 401
          next({error: verification.error}.to_json)
        end

        message = @ap_inbox.ingest(env.request.body)
        env.response.status_code = 202
        if message
          {accepted: true, duplicate: false, message_id: message.id}.to_json
        else
          {accepted: true, duplicate: true}.to_json
        end
      rescue ex : ActivityPubInboxService::InvalidActivity
        env.response.status_code = 422
        {error: ex.message}.to_json
      rescue ex : ArgumentError
        env.response.status_code = 404
        {error: ex.message}.to_json
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

      post "/api/preview/render" do |env|
        env.response.content_type = "application/json"
        @typst_preview.render(env.request.body).to_json
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
      rescue ex : TypstPreviewService::UnavailableError
        env.response.status_code = 503
        {error: ex.message}.to_json
      rescue ex : TypstPreviewService::RenderError
        env.response.status_code = 500
        {error: ex.message}.to_json
      end

      get "/api/meshtastic/hardware_trial" do |env|
        env.response.content_type = "application/json"
        @hardware_trials.as_json
      end

      get "/api/peer/outbound_queue" do |env|
        env.response.content_type = "application/json"
        limit = env.params.query["limit"]?.try(&.to_i?) || 25
        @peer_transport.queue(limit.clamp(1, 100)).to_json
      end

      get "/api/peer/outbound_queue/:id/payload" do |env|
        env.response.content_type = "application/json"
        {
          id:          env.params.url["id"],
          payload_b64: @peer_transport.payload_base64(env.params.url["id"]),
        }.to_json
      rescue ex : KeyError
        env.response.status_code = 404
        {error: "Unknown relay job id"}.to_json
      rescue ex : ArgumentError
        env.response.status_code = 422
        {error: ex.message}.to_json
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

      post "/api/peer/inbox_payload" do |env|
        env.response.content_type = "application/json"
        message = @peer_relay.receive_payload(env.request.body)
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
