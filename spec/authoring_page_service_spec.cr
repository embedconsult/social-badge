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
    html.should contain("fetch(\"/api/messages\"")
    html.should contain("fetch(\"/api/preview/render\"")
    html.should contain("trustChip.textContent = trustLevel")
    html.should_not contain("id=\"artifact-list\"")
    html.should_not contain("id=\"font-profile\"")
    html.should_not contain("id=\"prev-page\"")
    html.should_not contain("id=\"next-page\"")
    html.should contain("Typst-style control directives are non-printing")
    html.should contain("#font(&quot;nsm&quot;)")
    html.should contain("#place(bottom + right)[#qr(&quot;https://bbb.io/badge&quot;)]")
    html.should contain("#event(&quot;2026-03-01 18:30&quot;, &quot;Title&quot;, &quot;Location&quot;)")
    html.should contain("id=\"message-artifacts\"")
    html.should contain("id=\"typst-render\"")
    html.should contain("id=\"preview-status\"")
    html.should contain("fixed 320x240")
    html.should contain("id=\"preview-config\"")
    html.should contain("Noto Sans Mono")
  end
end
