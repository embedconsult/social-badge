require "json"
require "file_utils"
require "./models"

module SocialBadge
  struct TimelineSnapshot
    include JSON::Serializable

    getter identity : Identity
    getter messages : Array(Message)
    getter seen_dedupe_keys : Array(String)

    def initialize(
      @identity : Identity,
      @messages : Array(Message),
      @seen_dedupe_keys : Array(String),
    )
    end
  end

  struct RelayQueueSnapshot
    include JSON::Serializable

    getter jobs : Array(OutboundRelayJob)

    def initialize(@jobs : Array(OutboundRelayJob))
    end
  end

  class PersistenceService
    DEFAULT_DATA_DIR = "data"

    def initialize(@root_dir : String = ENV["SOCIAL_BADGE_DATA_DIR"]? || DEFAULT_DATA_DIR)
      FileUtils.mkdir_p(@root_dir)
    end

    def load_timeline : TimelineSnapshot?
      read_json(timeline_path, TimelineSnapshot)
    end

    def save_timeline(snapshot : TimelineSnapshot) : Nil
      write_json(timeline_path, snapshot)
    end

    def load_relay_queue : RelayQueueSnapshot?
      read_json(relay_queue_path, RelayQueueSnapshot)
    end

    def save_relay_queue(snapshot : RelayQueueSnapshot) : Nil
      write_json(relay_queue_path, snapshot)
    end

    private def timeline_path : String
      File.join(@root_dir, "timeline.json")
    end

    private def relay_queue_path : String
      File.join(@root_dir, "relay_queue.json")
    end

    private def read_json(path : String, klass : T.class) : T? forall T
      return nil unless File.exists?(path)
      klass.from_json(File.read(path))
    rescue JSON::ParseException | JSON::SerializableError
      STDERR.puts "[social-badge] Failed to read #{path}; ignoring corrupt data."
      nil
    end

    private def write_json(path : String, payload) : Nil
      temp_path = "#{path}.tmp"
      File.write(temp_path, payload.to_json)
      File.rename(temp_path, path)
    end
  end
end
