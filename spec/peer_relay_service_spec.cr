require "./spec_helper"

describe SocialBadge::PeerRelayService do
  it "normalizes malformed relay JSON to a compact error" do
    timeline = SocialBadge::TimelineService.new
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::PeerRelayService.new(transport)

    expect_raises(ArgumentError, "Invalid relay payload") do
      service.enqueue(IO::Memory.new("not-json"))
    end
  end

  it "normalizes malformed inbox JSON to a compact error" do
    timeline = SocialBadge::TimelineService.new
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::PeerRelayService.new(transport)

    expect_raises(ArgumentError, "Invalid peer envelope") do
      service.receive(IO::Memory.new("{}"))
    end
  end

  it "accepts inbound base64-encoded Meshtastic payloads" do
    timeline = SocialBadge::TimelineService.new
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::PeerRelayService.new(transport)

    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "payload-1",
      author_id: "peer:radio",
      body: "radio frame",
      created_at_unix_ms: Time.utc.to_unix_ms,
      trust_level: SocialBadge::TrustLevel::PeerAttested,
      dedupe_key: "0123456789abcdef0123456789abcdef",
      origin: "peer"
    )

    payload_b64 = SocialBadge::MeshtasticAdapterService.new.encode_base64(envelope)
    accepted = service.receive_payload(IO::Memory.new({payload_b64: payload_b64}.to_json))

    accepted.should_not be_nil
    timeline.timeline.first.id.should eq("payload-1")
  end
end
