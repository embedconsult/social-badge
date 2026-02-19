require "./spec_helper"

describe SocialBadge::MessageCreationService do
  it "creates a message from valid request JSON" do
    timeline = SocialBadge::TimelineService.new
    service = SocialBadge::MessageCreationService.new(timeline)

    message = service.create(IO::Memory.new(%({"body":"hello mesh"})))

    message.body.should eq("hello mesh")
    timeline.timeline.first.id.should eq(message.id)
  end

  it "returns a validation error for malformed payload" do
    timeline = SocialBadge::TimelineService.new
    service = SocialBadge::MessageCreationService.new(timeline)

    expect_raises(ArgumentError, "Invalid message payload") do
      service.create(IO::Memory.new("not-json"))
    end
  end

  it "returns a validation error for missing body" do
    timeline = SocialBadge::TimelineService.new
    service = SocialBadge::MessageCreationService.new(timeline)

    expect_raises(ArgumentError, "Invalid message payload") do
      service.create(IO::Memory.new("{}"))
    end
  end

  it "returns a validation error when no request body is provided" do
    timeline = SocialBadge::TimelineService.new
    service = SocialBadge::MessageCreationService.new(timeline)

    expect_raises(ArgumentError, "Invalid message payload") do
      service.create(nil)
    end
  end
end
