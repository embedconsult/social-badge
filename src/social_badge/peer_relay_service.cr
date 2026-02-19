require "json"
require "./peer_transport_service"

module SocialBadge
  class PeerRelayService
    ERROR_PREFIX       = "Invalid relay payload"
    INBOX_ERROR_PREFIX = "Invalid peer envelope"

    def initialize(@transport : PeerTransportService)
    end

    def enqueue(request_body : IO?) : OutboundRelayJob
      payload = parse_relay_payload(request_body)
      @transport.enqueue(payload.peer_url, payload.message_id)
    end

    def receive(request_body : IO?) : Message?
      envelope = parse_inbox_payload(request_body)
      @transport.receive(envelope)
    end

    private def parse_relay_payload(request_body : IO?) : EnqueueRelayRequest
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      EnqueueRelayRequest.from_json(raw_payload)
    rescue JSON::ParseException | JSON::SerializableError
      raise ArgumentError.new(ERROR_PREFIX)
    end

    private def parse_inbox_payload(request_body : IO?) : MeshtasticEnvelope
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      MeshtasticEnvelope.from_json(raw_payload)
    rescue JSON::ParseException | JSON::SerializableError
      raise ArgumentError.new(INBOX_ERROR_PREFIX)
    end
  end
end
