require "json"

module SocialBadge
  class HardwareTrialService
    include JSON::Serializable

    struct ChecklistItem
      include JSON::Serializable

      getter id : String
      getter category : String
      getter check : String
      getter rationale : String

      def initialize(@id : String, @category : String, @check : String, @rationale : String)
      end
    end

    getter protocol_scope : String
    getter caution : String
    getter checklist : Array(ChecklistItem)

    def initialize
      @protocol_scope = "Meshtastic peer transport over LoRa radio links"
      @caution = "LoRaWAN network-server integration is out of scope for v1 in this repository"
      @checklist = [
        ChecklistItem.new(
          id: "payload-budget",
          category: "encoding",
          check: "Verify encoded payloads remain at or under 233-byte Data.payload limits under realistic UTF-8 content.",
          rationale: "Prevents radio drops caused by envelope expansion and keeps authored content relay-friendly."
        ),
        ChecklistItem.new(
          id: "dedupe-replay",
          category: "transport",
          check: "Replay duplicated frames across multiple nodes and confirm single-store behavior by message_id and dedupe_key.",
          rationale: "Suppresses rebroadcast loops and duplicate timeline entries in mesh relay paths."
        ),
        ChecklistItem.new(
          id: "retry-backoff",
          category: "reliability",
          check: "Introduce packet loss and verify queue transitions through pending/delivered/failed with bounded retry backoff.",
          rationale: "Confirms reliability behavior under real RF interference and intermittent peer reachability."
        ),
        ChecklistItem.new(
          id: "bridge-policy",
          category: "policy",
          check: "Validate channel-to-public timeline mapping and ensure mesh traffic is not implicitly public.",
          rationale: "Avoids accidental publication of private channel traffic through public web bridges."
        ),
        ChecklistItem.new(
          id: "e2e-success",
          category: "acceptance",
          check: "Run two-badge exchange with web-forwarded public posts and confirm federation visibility path remains intact.",
          rationale: "Matches the repository's v1 success criteria for hardware-backed operation."
        ),
      ]
    end

    def as_json : String
      {
        protocol_scope: protocol_scope,
        caution:        caution,
        checklist:      checklist,
      }.to_json
    end
  end
end
