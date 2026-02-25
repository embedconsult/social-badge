require "json"
require "./timeline_service"

module SocialBadge
  class ActivityPubInboxService
    class InvalidActivity < ArgumentError
    end

    def initialize(@timeline : TimelineService)
    end

    def ingest(request_body : IO?) : Message?
      raw_payload = request_body.try(&.gets_to_end) || "{}"
      data = JSON.parse(raw_payload)
      activity_type = data["type"]?.try(&.as_s?)
      raise InvalidActivity.new("Unsupported activity type") unless activity_type == "Create"

      activity_id = data["id"]?.try(&.as_s?)
      actor_id = data["actor"]?.try(&.as_s?)
      object = data["object"]?
      raise InvalidActivity.new("Missing activity object") unless object

      note_type = object["type"]?.try(&.as_s?)
      raise InvalidActivity.new("Unsupported object type") unless note_type == "Note"

      content = object["content"]?.try(&.as_s?) || ""
      content = sanitize_content(content)
      raise InvalidActivity.new("Missing content") if content.blank?

      published = object["published"]?.try(&.as_s?) || data["published"]?.try(&.as_s?)
      created_at = parse_time(published)

      object_id = object["id"]?.try(&.as_s?)
      activity_id ||= object_id
      actor_id ||= object["attributedTo"]?.try(&.as_s?)

      raise InvalidActivity.new("Missing activity id") unless activity_id
      raise InvalidActivity.new("Missing actor id") unless actor_id

      @timeline.receive_activity(
        activity_id: activity_id,
        actor_id: actor_id,
        body: content,
        created_at: created_at,
      )
    rescue JSON::ParseException
      raise InvalidActivity.new("Invalid JSON payload")
    rescue ex : ArgumentError
      raise InvalidActivity.new(ex.message)
    end

    private def sanitize_content(content : String) : String
      sanitized = content.gsub(/<[^>]+>/, "")
      sanitized.strip
    end

    private def parse_time(value : String?) : Time
      return Time.utc unless value
      Time.parse_rfc3339(value)
    rescue Time::Format::Error
      Time.utc
    end
  end
end
