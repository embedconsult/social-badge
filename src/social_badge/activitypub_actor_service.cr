require "./activitypub_models"
require "./activitypub_config"

module SocialBadge
  class ActivityPubActorService
    def initialize(@config : ActivityPubConfig = ActivityPubConfig.new)
    end

    def actor_for(name : String) : ActivityPubActor
      raise ArgumentError.new("Unknown actor") unless name == @config.actor_name

      ActivityPubActor.new(
        context: ["https://www.w3.org/ns/activitystreams"],
        id: @config.actor_id,
        type: "Person",
        preferred_username: @config.actor_name,
        name: @config.actor_display_name,
        inbox: @config.inbox_url,
        outbox: @config.outbox_url,
        public_key: ActivityPubPublicKey.new(
          id: @config.public_key_id,
          owner: @config.actor_id,
          public_key_pem: @config.public_key_pem,
        ),
      )
    end
  end
end
