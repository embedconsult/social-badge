require "base64"
require "json"
require "uuid"
require "./models"

module SocialBadge
  class MeshtasticAdapterService
    MAX_PAYLOAD_BYTES = 233

    TRUST_LEVEL_TO_CODE = {
      TrustLevel::FullOidcVerified => 2,
      TrustLevel::PeerAttested     => 1,
      TrustLevel::Unverified       => 0,
    }

    CODE_TO_TRUST_LEVEL = {
      2 => TrustLevel::FullOidcVerified,
      1 => TrustLevel::PeerAttested,
      0 => TrustLevel::Unverified,
    }

    def encode(envelope : MeshtasticEnvelope) : Bytes
      payload = JSON.build do |json|
        json.object do
          json.field "m", envelope.message_id
          json.field "a", envelope.author_id
          json.field "b", envelope.body
          json.field "t", envelope.created_at_unix_ms
          json.field "k", envelope.dedupe_key
          json.field "o", envelope.origin
          json.field "h", envelope.relay_hops
          json.field "l", TRUST_LEVEL_TO_CODE[envelope.trust_level]
        end
      end.to_slice

      raise ArgumentError.new("Encoded Meshtastic payload exceeds #{MAX_PAYLOAD_BYTES} bytes") if payload.size > MAX_PAYLOAD_BYTES
      payload
    end

    def encode_base64(envelope : MeshtasticEnvelope) : String
      Base64.strict_encode(encode(envelope))
    end

    def decode(payload : Bytes) : MeshtasticEnvelope
      raise ArgumentError.new("Meshtastic payload must not be empty") if payload.empty?
      raw = String.new(payload)
      data = JSON.parse(raw)

      trust_code = data["l"].as_i
      trust_level = CODE_TO_TRUST_LEVEL[trust_code]?
      raise ArgumentError.new("Invalid Meshtastic trust level code") unless trust_level

      MeshtasticEnvelope.new(
        message_id: data["m"].as_s,
        author_id: data["a"].as_s,
        body: data["b"].as_s,
        created_at_unix_ms: data["t"].as_i64,
        trust_level: trust_level,
        dedupe_key: data["k"].as_s,
        origin: data["o"].as_s,
        relay_hops: data["h"].as_i
      )
    rescue JSON::ParseException | KeyError | TypeCastError
      raise ArgumentError.new("Invalid Meshtastic payload")
    end

    def decode_base64(encoded : String) : MeshtasticEnvelope
      decode(Base64.decode(encoded))
    rescue Base64::Error
      raise ArgumentError.new("Invalid Meshtastic payload")
    end
  end
end
