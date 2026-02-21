require "./spec_helper"

describe SocialBadge::TypstPreviewService do
  it "reports startup diagnostics" do
    service = SocialBadge::TypstPreviewService.new
    status = service.startup_status

    status.detail.should_not be_empty
  end

  it "rejects invalid JSON payloads" do
    service = SocialBadge::TypstPreviewService.new

    expect_raises(ArgumentError, "Invalid preview payload") do
      service.render(IO::Memory.new("{not-json"))
    end
  end

  it "rejects messages longer than the model max" do
    service = SocialBadge::TypstPreviewService.new
    payload = {body: "x" * (SocialBadge::Message::MAX_BODY_LENGTH + 1)}.to_json

    expect_raises(ArgumentError, "Message body exceeds #{SocialBadge::Message::MAX_BODY_LENGTH} characters") do
      service.render(IO::Memory.new(payload))
    end
  end

  it "renders inline #link syntax as an SVG link" do
    next unless (Process.find_executable("typst") || (File.info?(File.join(SocialBadge::TypstPreviewService::ROOT_DIR, "lib/typst/bin/typst")).try { |info|
                  perms = info.permissions
                  perms.owner_execute? || perms.group_execute? || perms.other_execute?
                } || false))

    service = SocialBadge::TypstPreviewService.new
    payload = {
      body: "Learn more at #link(\"https://bbb.io/badge\")[Badge]",
    }.to_json

    rendered = service.render(IO::Memory.new(payload))
    rendered.svg.should contain("https://bbb.io/badge")
  end

  it "renders message previews as SVG via Typst" do
    next unless (Process.find_executable("typst") || (File.info?(File.join(SocialBadge::TypstPreviewService::ROOT_DIR, "lib/typst/bin/typst")).try { |info|
                  perms = info.permissions
                  perms.owner_execute? || perms.group_execute? || perms.other_execute?
                } || false))

    service = SocialBadge::TypstPreviewService.new
    payload = {
      body: "# Beagle\n\n#place(bottom+right)[#qr(\"https://bbb.io/badge\")]",
    }.to_json

    rendered = service.render(IO::Memory.new(payload))
    rendered.cache_key.should_not be_empty
    rendered.render_spec_version.should eq("msg_320x240_v1")
    rendered.svg.should contain("<svg")
  end
end
