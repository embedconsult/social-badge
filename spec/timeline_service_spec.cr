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
end
