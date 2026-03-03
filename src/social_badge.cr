require "./social_badge/version"
require "./social_badge/models"
require "./social_badge/authoring_page_service"
require "./social_badge/timeline_service"
require "./social_badge/message_creation_service"
require "./social_badge/policy_service"
require "./social_badge/typst_preview_service"
require "./social_badge/meshtastic_envelope_service"
require "./social_badge/meshtastic_adapter_service"
require "./social_badge/linux_wio_sx1262_driver_service"
require "./social_badge/peer_transport_service"
require "./social_badge/peer_relay_service"
require "./social_badge/hardware_trial_service"
require "./social_badge/activitypub_config"
require "./social_badge/activitypub_models"
require "./social_badge/webfinger_service"
require "./social_badge/activitypub_actor_service"
require "./social_badge/activitypub_inbox_service"
require "./social_badge/activitypub_outbox_service"
require "./social_badge/http_signature_service"
require "./social_badge/web_app"

module SocialBadge
  def self.boot
    app = WebApp.new
    app.routes
  end
end
