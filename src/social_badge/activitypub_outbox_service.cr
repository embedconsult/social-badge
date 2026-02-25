require "./activitypub_models"
require "./activitypub_config"
require "./timeline_service"

module SocialBadge
  class ActivityPubOutboxService
    def initialize(
      @timeline : TimelineService,
      @config : ActivityPubConfig = ActivityPubConfig.new,
    )
    end

    def outbox_for(name : String, limit : Int32 = 25) : ActivityPubOrderedCollection
      raise ArgumentError.new("Unknown actor") unless name == @config.actor_name

      messages = @timeline.timeline(limit.clamp(1, 100))
      activities = messages.map { |message| build_activity(message) }

      ActivityPubOrderedCollection.new(
        context: ["https://www.w3.org/ns/activitystreams"],
        id: @config.outbox_url,
        type: "OrderedCollection",
        totalItems: activities.size,
        orderedItems: activities,
      )
    end

    private def build_activity(message : Message) : ActivityPubCreate
      note = ActivityPubNote.new(
        id: "#{@config.base_url}/objects/#{message.id}",
        type: "Note",
        content: message.body,
        media_type: "text/plain",
        attributedTo: @config.actor_id,
        published: message.created_at.to_rfc3339,
      )

      ActivityPubCreate.new(
        context: ["https://www.w3.org/ns/activitystreams"],
        id: "#{@config.base_url}/activities/#{message.id}",
        type: "Create",
        actor: @config.actor_id,
        object: note,
        published: message.created_at.to_rfc3339,
      )
    end
  end
end
