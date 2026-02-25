require "uri"

module SocialBadge
  class ActivityPubConfig
    getter base_url : String
    getter actor_name : String
    getter actor_display_name : String
    getter public_key_pem : String
    getter allow_unsigned : Bool
    getter skip_signature_verify : Bool

    def initialize(
      @base_url : String = ENV["SOCIAL_BADGE_BASE_URL"]? || "http://127.0.0.1:30000",
      @actor_name : String = ENV["SOCIAL_BADGE_ACTOR_NAME"]? || "demo",
      @actor_display_name : String = ENV["SOCIAL_BADGE_ACTOR_DISPLAY_NAME"]? || "Demo Peer",
      @public_key_pem : String = ENV["SOCIAL_BADGE_ACTOR_PUBLIC_KEY_PEM"]? || "UNCONFIGURED",
      @allow_unsigned : Bool = (ENV["SOCIAL_BADGE_ALLOW_UNSIGNED_AP"]? || "false") == "true",
      @skip_signature_verify : Bool = (ENV["SOCIAL_BADGE_SKIP_SIGNATURE_VERIFY"]? || "false") == "true",
    )
    end

    def domain : String
      URI.parse(@base_url).host || "localhost"
    rescue URI::Error
      "localhost"
    end

    def actor_id : String
      "#{@base_url}/users/#{@actor_name}"
    end

    def inbox_url : String
      "#{actor_id}/inbox"
    end

    def outbox_url : String
      "#{actor_id}/outbox"
    end

    def public_key_id : String
      "#{actor_id}#main-key"
    end
  end
end
