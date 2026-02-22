require "./spec_helper"

describe SocialBadge::PeerTransportService do
  it "enqueues relay jobs for existing timeline messages" do
    timeline = SocialBadge::TimelineService.new
    posted = timeline.post("hello peer")
    service = SocialBadge::PeerTransportService.new(timeline)

    job = service.enqueue("https://peer.example", posted.id)

    job.peer_url.should eq("https://peer.example")
    job.status.should eq(SocialBadge::RelayJobStatus::Pending)
    service.queue.first.id.should eq(job.id)
  end

  it "rejects malformed peer urls" do
    timeline = SocialBadge::TimelineService.new
    posted = timeline.post("hello peer")
    service = SocialBadge::PeerTransportService.new(timeline)

    expect_raises(ArgumentError, "Invalid peer URL") do
      service.enqueue("peer.example", posted.id)
    end
  end

  it "applies retry policy and transitions to failed after max attempts" do
    timeline = SocialBadge::TimelineService.new
    posted = timeline.post("retry me")
    service = SocialBadge::PeerTransportService.new(timeline, max_attempts: 2)

    job = service.enqueue("https://peer.example", posted.id)
    failed_once = service.mark_failure(job.id)

    failed_once.attempts.should eq(1)
    failed_once.status.should eq(SocialBadge::RelayJobStatus::Pending)

    failed_twice = service.mark_failure(job.id)
    failed_twice.attempts.should eq(2)
    failed_twice.status.should eq(SocialBadge::RelayJobStatus::Failed)
  end

  it "accepts inbound envelope messages" do
    timeline = SocialBadge::TimelineService.new
    service = SocialBadge::PeerTransportService.new(timeline)

    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "peer-message-1",
      author_id: "peer:demo",
      body: "from peer",
      created_at_unix_ms: Time.utc.to_unix_ms,
      trust_level: SocialBadge::TrustLevel::PeerAttested,
      dedupe_key: "dedupe-1",
      origin: "peer"
    )

    accepted = service.receive(envelope)
    duplicate = service.receive(envelope)

    accepted.should_not be_nil
    duplicate.should be_nil
    timeline.timeline.first.id.should eq("peer-message-1")
  end

  it "exports relay payloads in base64 for radio handoff" do
    timeline = SocialBadge::TimelineService.new
    posted = timeline.post("hello radio")
    service = SocialBadge::PeerTransportService.new(timeline)

    job = service.enqueue("https://peer.example", posted.id)
    payload_b64 = service.payload_base64(job.id)
    decoded = SocialBadge::MeshtasticAdapterService.new.decode_base64(payload_b64)

    decoded.message_id.should eq(posted.id)
    decoded.body.should eq("hello radio")
  end
end
