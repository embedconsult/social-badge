require "./spec_helper"

describe SocialBadge::TimelineService do
  it "creates and returns timeline messages newest first" do
    service = SocialBadge::TimelineService.new

    first = service.post("hello mesh")
    second = service.post("hello federation")

    timeline = service.timeline
    timeline.size.should eq(2)
    timeline.first.id.should eq(second.id)
    timeline.last.id.should eq(first.id)
  end

  it "enforces meshtastic-friendly message length" do
    service = SocialBadge::TimelineService.new

    expect_raises(ArgumentError) do
      service.post("x" * (SocialBadge::Message::MAX_BODY_LENGTH + 1))
    end
  end

  it "rejects blank messages after trimming" do
    service = SocialBadge::TimelineService.new

    expect_raises(ArgumentError, /must not be blank/) do
      service.post("   ")
    end
  end

  it "ingests peer envelopes and deduplicates on message id" do
    service = SocialBadge::TimelineService.new

    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "peer-1",
      author_id: "peer:demo",
      body: "hello from peer",
      created_at_unix_ms: Time.utc.to_unix_ms,
      trust_level: SocialBadge::TrustLevel::PeerAttested,
      dedupe_key: "abc123",
      origin: "peer"
    )

    first_ingest = service.receive(envelope)
    second_ingest = service.receive(envelope)

    first_ingest.should_not be_nil
    second_ingest.should be_nil
    service.timeline.first.id.should eq("peer-1")
  end
end
