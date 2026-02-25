require "./spec_helper"

module SocialBadge
  describe ActivityPubOutboxService do
    it "renders messages as create activities" do
      timeline = TimelineService.new
      message = timeline.post("hello world")
      service = ActivityPubOutboxService.new(timeline)

      outbox = service.outbox_for(ActivityPubConfig.new.actor_name)

      outbox.orderedItems.size.should eq(1)
      outbox.orderedItems.first.object.content.should eq("hello world")
      outbox.orderedItems.first.object.id.should contain(message.id)
    end
  end
end
