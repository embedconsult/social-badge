require "json"

module SocialBadge
  enum TrustLevel
    FullOidcVerified
    PeerAttested
    Unverified
  end

  struct Identity
    include JSON::Serializable

    getter id : String
    getter display_name : String
    getter trust_level : TrustLevel

    def initialize(@id : String, @display_name : String, @trust_level : TrustLevel = TrustLevel::Unverified)
    end
  end

  struct Message
    include JSON::Serializable

    MAX_BODY_LENGTH = 280

    getter id : String
    getter author_id : String
    getter body : String
    getter created_at : Time

    def initialize(@id : String, @author_id : String, @body : String, @created_at : Time = Time.utc)
      raise ArgumentError.new("Message body must not be blank") if @body.blank?
      raise ArgumentError.new("Message body exceeds #{MAX_BODY_LENGTH} characters") if @body.size > MAX_BODY_LENGTH
    end
  end
end
