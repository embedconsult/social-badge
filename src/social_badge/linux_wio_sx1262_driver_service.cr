require "base64"
require "digest/sha1"
require "json"
require "uuid"
require "./models"
require "./peer_transport_service"

module SocialBadge
  class LinuxWioSx1262DriverService
    PORTNUM_TEXT_MESSAGE_APP = "TEXT_MESSAGE_APP"

    def initialize(@transport : PeerTransportService)
    end

    def tx_frame(job_id : String) : LinuxWioSx1262TxFrame
      LinuxWioSx1262TxFrame.new(
        job_id: job_id,
        payload_b64: @transport.payload_base64(job_id),
        portnum: PORTNUM_TEXT_MESSAGE_APP,
      )
    end

    def receive_frame(request_body : IO?) : Message?
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      data = JSON.parse(raw_payload)

      if payload_b64 = extract_payload_b64(data)
        begin
          return @transport.receive_payload(payload_b64)
        rescue ArgumentError
          return receive_supercon_payload(data, payload_b64)
        end
      end

      if text = extract_text(data)
        return @transport.receive(supercon_envelope(text, extract_source_id(data)))
      end

      raise ArgumentError.new("Invalid Linux Wio SX1262 frame")
    rescue JSON::ParseException
      raise ArgumentError.new("Invalid Linux Wio SX1262 frame")
    end

    private def receive_supercon_payload(data : JSON::Any, payload_b64 : String) : Message?
      text = String.new(Base64.decode(payload_b64))
      @transport.receive(supercon_envelope(text, extract_source_id(data)))
    rescue Base64::Error | ArgumentError
      raise ArgumentError.new("Invalid Linux Wio SX1262 frame")
    end

    private def supercon_envelope(text : String, source_id : String) : MeshtasticEnvelope
      message_fingerprint = Digest::SHA1.hexdigest(text)
      message_id = "sx1262-#{message_fingerprint[0, 12]}"

      MeshtasticEnvelope.new(
        message_id: message_id,
        author_id: source_id,
        body: text,
        created_at_unix_ms: Time.utc.to_unix_ms,
        trust_level: TrustLevel::Unverified,
        dedupe_key: message_fingerprint[0, 32],
        origin: "supercon",
        relay_hops: 0,
      )
    end

    private def extract_payload_b64(data : JSON::Any) : String?
      candidates = {
        ["payload_b64"],
        ["payload"],
        ["decoded", "payload"],
        ["packet", "decoded", "payload"],
        ["rx", "packet", "decoded", "payload"],
      }

      candidates.each do |path|
        value = dig_string(data, path)
        return value if value
      end
      nil
    end

    private def extract_text(data : JSON::Any) : String?
      dig_string(data, ["text"]) ||
        dig_string(data, ["message"]) ||
        dig_string(data, ["decoded", "text"]) ||
        dig_string(data, ["packet", "decoded", "text"])
    end

    private def extract_source_id(data : JSON::Any) : String
      source = dig_string(data, ["from"]) ||
               dig_string(data, ["from_id"]) ||
               dig_string(data, ["packet", "from"])

      return source unless source.nil? || source.blank?
      "mesh:unknown"
    end

    private def dig_string(data : JSON::Any, path : Array(String)) : String?
      current = data
      path.each do |segment|
        hash = current.as_h?
        return nil unless hash
        current = hash[segment]?
        return nil unless current
      end
      current.as_s?
    end
  end
end
