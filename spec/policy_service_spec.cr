require "./spec_helper"

describe SocialBadge::PolicyService do
  it "provides v1 trust defaults" do
    service = SocialBadge::PolicyService.new

    policy = service.trust_policy
    policy.downgrade_interval_days.should eq(30)
    policy.revocation_ttl_days.should eq(7)
    policy.local_approval_required.should be_true
  end
end
