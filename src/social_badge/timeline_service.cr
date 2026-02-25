require "uuid"
require "set"
require "./models"
require "./persistence_service"

module SocialBadge
  class TimelineService
    getter! identity : Identity

    def initialize(@persistence : PersistenceService? = nil)
      snapshot = @persistence.try(&.load_timeline)
      if snapshot
        @identity = snapshot.identity
        @messages = snapshot.messages
        @messages_by_id = @messages.each_with_object({} of String => Message) do |message, acc|
          acc[message.id] = message
        end
        @seen_dedupe_keys = Set(String).new
        snapshot.seen_dedupe_keys.each { |key| @seen_dedupe_keys << key }
      else
        @identity = Identity.new(
          id: "oidc:forum.beagleboard.org:demo",
          display_name: "Demo Peer",
          trust_level: TrustLevel::Unverified
        )
        @messages = [] of Message
        @messages_by_id = {} of String => Message
        @seen_dedupe_keys = Set(String).new
      end
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
      persist!
    end

    private def persist!
      return unless @persistence
      snapshot = TimelineSnapshot.new(
        identity: @identity,
        messages: @messages,
        seen_dedupe_keys: @seen_dedupe_keys.to_a,
      )
      @persistence.not_nil!.save_timeline(snapshot)
    end
  end
end
