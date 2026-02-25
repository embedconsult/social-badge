require "./spec_helper"

module SocialBadge
  describe WebFingerService do
    it "returns a webfinger response for the configured actor" do
      config = ActivityPubConfig.new
      service = WebFingerService.new(config)
      resource = "acct:#{config.actor_name}@#{config.domain}"

      response = service.lookup(resource)

      response.subject.should eq(resource)
      response.links.size.should eq(1)
      response.links.first.href.should eq(config.actor_id)
    end

    it "rejects unknown resources" do
      service = WebFingerService.new(ActivityPubConfig.new)
      expect_raises(ArgumentError) { service.lookup("acct:unknown@example.com") }
    end
  end
end
