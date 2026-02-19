require "uuid"
require "set"
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
      @messages_by_id = {} of String => Message
      @seen_dedupe_keys = Set(String).new
    end

    def timeline(limit : Int32 = 25) : Array(Message)
      @messages.last(limit).reverse
    end

    def message(message_id : String) : Message?
      @messages_by_id[message_id]?
    end

    def post(body : String) : Message
      message = Message.new(
        id: UUID.random.to_s,
        author_id: identity.id,
        body: body.strip,
        created_at: Time.utc
      )
      store(message)
      message
    end

    def receive(envelope : MeshtasticEnvelope) : Message?
      return nil if @messages_by_id.has_key?(envelope.message_id)
      return nil if @seen_dedupe_keys.includes?(envelope.dedupe_key)

      message = Message.new(
        id: envelope.message_id,
        author_id: envelope.author_id,
        body: envelope.body,
        created_at: Time.unix_ms(envelope.created_at_unix_ms)
      )
      store(message, envelope.dedupe_key)
      message
    end

    private def store(message : Message, dedupe_key : String? = nil)
      @messages << message
      @messages_by_id[message.id] = message
      @seen_dedupe_keys << dedupe_key if dedupe_key
    end
  end
end
