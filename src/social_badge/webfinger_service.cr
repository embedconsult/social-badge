require "./activitypub_models"
require "./activitypub_config"

module SocialBadge
  class WebFingerService
    def initialize(@config : ActivityPubConfig = ActivityPubConfig.new)
    end

    def lookup(resource : String) : WebFingerResponse
      subject = "acct:#{@config.actor_name}@#{@config.domain}"
      unless resource == subject
        raise ArgumentError.new("Unknown WebFinger resource")
      end

      WebFingerResponse.new(
        subject: subject,
        links: [
          WebFingerLink.new(
            rel: "self",
            type: "application/activity+json",
            href: @config.actor_id,
          ),
        ],
      )
    end
  end
end
