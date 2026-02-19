require "digest/sha256"
require "./models"

module SocialBadge
  class MeshtasticEnvelopeService
    DEDUPE_KEY_HEX_LENGTH = 32

    def build_from(message : Message, trust_level : TrustLevel, origin : String = "local") : MeshtasticEnvelope
      MeshtasticEnvelope.new(
        message_id: message.id,
        author_id: message.author_id,
        body: message.body,
        created_at_unix_ms: message.created_at.to_unix_ms,
        trust_level: trust_level,
        dedupe_key: dedupe_key_for(message),
        origin: origin,
        relay_hops: 0
      )
    end

    private def dedupe_key_for(message : Message) : String
      Digest::SHA256.hexdigest("#{message.id}:#{message.author_id}:#{message.body}")[0, DEDUPE_KEY_HEX_LENGTH]
    end
  end
end
