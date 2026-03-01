require "./spec_helper"

describe SocialBadge::LinuxWioSx1262DriverService do
  it "exports Linux Wio SX1262 tx frames for queued jobs" do
    timeline = SocialBadge::TimelineService.new
    posted = timeline.post("radio-ready")
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::LinuxWioSx1262DriverService.new(transport)

    job = transport.enqueue("https://peer.example", posted.id)
    frame = service.tx_frame(job.id)

    frame.job_id.should eq(job.id)
    frame.portnum.should eq("TEXT_MESSAGE_APP")

    decoded = SocialBadge::MeshtasticAdapterService.new.decode_base64(frame.payload_b64)
    decoded.body.should eq("radio-ready")
  end

  it "ingests nested payload frames from Linux driver wrappers" do
    timeline = SocialBadge::TimelineService.new
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::LinuxWioSx1262DriverService.new(transport)

    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "mesh-driver-1",
      author_id: "peer:driver",
      body: "linux bridge",
      created_at_unix_ms: Time.utc.to_unix_ms,
      trust_level: SocialBadge::TrustLevel::PeerAttested,
      dedupe_key: "driver-dedupe-1",
      origin: "peer"
    )

    payload = SocialBadge::MeshtasticAdapterService.new.encode_base64(envelope)
    request_body = IO::Memory.new(%({"packet":{"decoded":{"payload":"#{payload}"}}}))

    accepted = service.receive_frame(request_body)

    accepted.should_not be_nil
    timeline.timeline.first.id.should eq("mesh-driver-1")
  end

  it "falls back to supercon-style text frames" do
    timeline = SocialBadge::TimelineService.new
    transport = SocialBadge::PeerTransportService.new(timeline)
    service = SocialBadge::LinuxWioSx1262DriverService.new(transport)

    accepted = service.receive_frame(IO::Memory.new(%({"from":"!beef","text":"hello from supercon"})))

    accepted.should_not be_nil
    accepted.not_nil!.author_id.should eq("!beef")
    accepted.not_nil!.body.should eq("hello from supercon")
  end
end
