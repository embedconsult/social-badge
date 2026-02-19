require "uuid"
require "./models"

module SocialBadge
  class TimelineService
    getter! identity : Identity

    def initialize
      @identity = Identity.new(
        id: "oidc:forum.beagleboard.org:demo",
        display_name: "Demo Peer",
        trust_level: TrustLevel::Unverified
      )
      @messages = [] of Message
    end

    def timeline(limit : Int32 = 25) : Array(Message)
      @messages.last(limit).reverse
    end

    def post(body : String) : Message
      message = Message.new(
        id: UUID.random.to_s,
        author_id: identity.id,
        body: body.strip,
        created_at: Time.utc
      )
      @messages << message
      message
    end
  end
end
