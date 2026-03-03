require "json"
require "digest/sha1"
require "uri"
require "./models"
require "./timeline_service"

module SocialBadge
  class LvglUiService
    UI_KIND             = "lvgl_home_v1"
    VIEWPORT_WIDTH      = 400
    VIEWPORT_HEIGHT     = 300
    MESSAGE_VIEW_WIDTH  = 320
    MESSAGE_VIEW_HEIGHT = 240
    STATUS_TEXT_LIMIT   =  64
    AUTHOR_TEXT_LIMIT   =  22

    struct Viewport
      include JSON::Serializable

      getter width : Int32
      getter height : Int32
      getter message_region_width : Int32
      getter message_region_height : Int32

      def initialize(
        @width : Int32,
        @height : Int32,
        @message_region_width : Int32,
        @message_region_height : Int32,
      )
      end
    end

    struct NavItem
      include JSON::Serializable

      getter id : String
      getter label : String
      getter selected : Bool

      def initialize(@id : String, @label : String, @selected : Bool = false)
      end
    end

    struct MessageRow
      include JSON::Serializable

      getter id : String
      getter author_label : String
      getter body_preview : String
      getter created_at_unix_ms : Int64
      getter has_url : Bool
      getter trust_level : TrustLevel

      def initialize(
        @id : String,
        @author_label : String,
        @body_preview : String,
        @created_at_unix_ms : Int64,
        @has_url : Bool,
        @trust_level : TrustLevel,
      )
      end
    end

    struct HomeModel
      include JSON::Serializable

      getter kind : String
      getter generated_at_unix_ms : Int64
      getter viewport : Viewport
      getter nav : Array(NavItem)
      getter identity_label : String
      getter trust_level : TrustLevel
      getter quick_actions : Array(String)
      getter message_rows : Array(MessageRow)
      getter queue_depth : Int32

      def initialize(
        @kind : String,
        @generated_at_unix_ms : Int64,
        @viewport : Viewport,
        @nav : Array(NavItem),
        @identity_label : String,
        @trust_level : TrustLevel,
        @quick_actions : Array(String),
        @message_rows : Array(MessageRow),
        @queue_depth : Int32,
      )
      end
    end

    def initialize(@timeline : TimelineService)
    end

    def home(limit : Int32 = 6) : HomeModel
      identity = @timeline.identity
      rows = @timeline.timeline(limit.clamp(1, 12)).map do |message|
        MessageRow.new(
          id: message.id,
          author_label: compact_author_label(message.author_id),
          body_preview: compact_status(message.body),
          created_at_unix_ms: message.created_at.to_unix_ms,
          has_url: has_url?(message.body),
          trust_level: identity.trust_level,
        )
      end

      HomeModel.new(
        kind: UI_KIND,
        generated_at_unix_ms: Time.utc.to_unix_ms,
        viewport: Viewport.new(
          width: VIEWPORT_WIDTH,
          height: VIEWPORT_HEIGHT,
          message_region_width: MESSAGE_VIEW_WIDTH,
          message_region_height: MESSAGE_VIEW_HEIGHT,
        ),
        nav: [
          NavItem.new(id: "timeline", label: "Timeline", selected: true),
          NavItem.new(id: "compose", label: "Compose"),
          NavItem.new(id: "relay", label: "Relay"),
        ],
        identity_label: compact_author_label(identity.display_name),
        trust_level: identity.trust_level,
        quick_actions: ["Ack", "👍", "Need details", "Relay"],
        message_rows: rows,
        queue_depth: 0,
      )
    end

    private def compact_status(text : String) : String
      normalized = text.gsub(/\s+/, " ").strip
      return normalized if normalized.size <= STATUS_TEXT_LIMIT
      "#{normalized[0, STATUS_TEXT_LIMIT - 1]}…"
    end

    private def compact_author_label(author : String) : String
      normalized = author.strip
      if normalized.starts_with?("oidc:")
        normalized = normalized.split(':').last?
      end
      normalized = "unknown" if normalized.empty?
      return normalized if normalized.size <= AUTHOR_TEXT_LIMIT
      hash = Digest::SHA1.hexdigest(normalized)[0, 4]
      "#{normalized[0, AUTHOR_TEXT_LIMIT - 5]}##{hash}"
    end

    private def has_url?(text : String) : Bool
      URI.extract(text).size > 0
    end
  end
end
