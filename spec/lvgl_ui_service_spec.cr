require "./spec_helper"

describe SocialBadge::LvglUiService do
  it "builds a compact LVGL home model with fixed geometry" do
    timeline = SocialBadge::TimelineService.new
    timeline.post("hello mesh from badge https://bbb.io/demo")
    timeline.post("second timeline item")

    service = SocialBadge::LvglUiService.new(timeline)
    model = service.home(2)

    model.kind.should eq("lvgl_home_v1")
    model.viewport.width.should eq(400)
    model.viewport.height.should eq(300)
    model.viewport.message_region_width.should eq(320)
    model.viewport.message_region_height.should eq(240)
    model.nav.size.should eq(3)
    model.message_rows.size.should eq(2)
    model.message_rows.first.has_url.should be_true
    model.quick_actions.should eq(["Ack", "👍", "Need details", "Relay"])
  end

  it "truncates long message previews for compact list rows" do
    timeline = SocialBadge::TimelineService.new
    timeline.post("a" * 100)
    service = SocialBadge::LvglUiService.new(timeline)

    row = service.home(1).message_rows.first

    row.body_preview.size.should eq(64)
    row.body_preview.ends_with?("…").should be_true
  end
end
