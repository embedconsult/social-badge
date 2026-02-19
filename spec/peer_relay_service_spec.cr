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
end
