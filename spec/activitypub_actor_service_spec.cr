require "./spec_helper"

module SocialBadge
  describe ActivityPubActorService do
    it "returns a person actor document" do
      config = ActivityPubConfig.new
      service = ActivityPubActorService.new(config)

      actor = service.actor_for(config.actor_name)

      actor.id.should eq(config.actor_id)
      actor.preferred_username.should eq(config.actor_name)
      actor.inbox.should eq(config.inbox_url)
      actor.outbox.should eq(config.outbox_url)
      actor.public_key.public_key_pem.should eq(config.public_key_pem)
    end
  end
end
