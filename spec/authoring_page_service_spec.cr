require "./spec_helper"

describe SocialBadge::AuthoringPageService do
  it "renders a web composer with fixed 320x240 preview geometry" do
    service = SocialBadge::AuthoringPageService.new
    identity = SocialBadge::Identity.new(
      id: "oidc:forum.beagleboard.org:demo",
      display_name: "Demo Peer",
      trust_level: SocialBadge::TrustLevel::Unverified
    )

    html = service.render(identity)

    html.should contain("id=\"message-input\"")
    html.should contain("left: 40px;")
    html.should contain("width: 320px;")
    html.should contain("height: 240px;")
    html.should contain("fetch('/api/messages'")
    html.should contain("trustChip.textContent = trustLevel")
  end
end
