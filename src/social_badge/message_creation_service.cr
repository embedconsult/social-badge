require "json"
require "./timeline_service"

module SocialBadge
  class MessageCreationService
    ERROR_PREFIX = "Invalid message payload"

    def initialize(@timeline : TimelineService)
    end

    def create(request_body : IO?) : Message
      payload = parse_payload(request_body)
      @timeline.post(payload.body)
    end

    private def parse_payload(request_body : IO?) : CreateMessageRequest
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      CreateMessageRequest.from_json(raw_payload)
    rescue JSON::ParseException | JSON::SerializableError
      raise ArgumentError.new(ERROR_PREFIX)
    end
  end
end
