require "json"

module SocialBadge
  enum TrustLevel
    FullOidcVerified
    PeerAttested
    Unverified
  end

  enum RelayJobStatus
    Pending
    Delivered
    Failed
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

  struct CreateMessageRequest
    include JSON::Serializable

    getter body : String
  end

  struct MeshtasticEnvelope
    include JSON::Serializable

    MAX_DEDUPE_KEY_LENGTH = 32
    MAX_ORIGIN_LENGTH     = 12
    MAX_RELAY_HOPS        =  7

    getter message_id : String
    getter author_id : String
    getter body : String
    getter created_at_unix_ms : Int64
    getter trust_level : TrustLevel
    getter dedupe_key : String
    getter origin : String
    getter relay_hops : Int32

    def initialize(
      @message_id : String,
      @author_id : String,
      @body : String,
      @created_at_unix_ms : Int64,
      @trust_level : TrustLevel,
      @dedupe_key : String,
      @origin : String,
      @relay_hops : Int32 = 0,
    )
      raise ArgumentError.new("Envelope body must not be blank") if @body.blank?
      raise ArgumentError.new("Envelope body exceeds #{Message::MAX_BODY_LENGTH} bytes") if @body.bytesize > Message::MAX_BODY_LENGTH
      raise ArgumentError.new("Envelope dedupe key must not be blank") if @dedupe_key.blank?
      raise ArgumentError.new("Envelope dedupe key exceeds #{MAX_DEDUPE_KEY_LENGTH} characters") if @dedupe_key.size > MAX_DEDUPE_KEY_LENGTH
      raise ArgumentError.new("Envelope origin must not be blank") if @origin.blank?
      raise ArgumentError.new("Envelope origin exceeds #{MAX_ORIGIN_LENGTH} characters") if @origin.size > MAX_ORIGIN_LENGTH
      raise ArgumentError.new("Envelope relay hops must be between 0 and #{MAX_RELAY_HOPS}") if @relay_hops < 0 || @relay_hops > MAX_RELAY_HOPS
    end
  end

  struct EnqueueRelayRequest
    include JSON::Serializable

    getter peer_url : String
    getter message_id : String
  end

  class OutboundRelayJob
    include JSON::Serializable

    getter id : String
    getter peer_url : String
    getter envelope : MeshtasticEnvelope
    property attempts : Int32
    property next_attempt_at : Time
    property status : RelayJobStatus

    def initialize(
      @id : String,
      @peer_url : String,
      @envelope : MeshtasticEnvelope,
      @attempts : Int32 = 0,
      @next_attempt_at : Time = Time.utc,
      @status : RelayJobStatus = RelayJobStatus::Pending,
    )
    end
  end
end
