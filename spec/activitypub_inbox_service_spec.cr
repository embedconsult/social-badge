require "./spec_helper"

module SocialBadge
  describe ActivityPubInboxService do
    it "ingests a create note activity" do
      timeline = TimelineService.new
      service = ActivityPubInboxService.new(timeline)

      payload = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "id"       => "https://example.com/activities/1",
        "type"     => "Create",
        "actor"    => "https://example.com/users/alice",
        "object"   => {
          "id"        => "https://example.com/notes/1",
          "type"      => "Note",
          "content"   => "Hi from AP",
          "published" => "2024-01-01T12:00:00Z",
        },
      }.to_json

      message = service.ingest(IO::Memory.new(payload))

      message.should_not be_nil
      message.not_nil!.body.should eq("Hi from AP")
      timeline.timeline(1).first.id.should eq("https://example.com/activities/1")
    end

    it "rejects invalid activities" do
      timeline = TimelineService.new
      service = ActivityPubInboxService.new(timeline)
      payload = {"type" => "Like"}.to_json

      expect_raises(ActivityPubInboxService::InvalidActivity) do
        service.ingest(IO::Memory.new(payload))
      end
    end
  end
end
