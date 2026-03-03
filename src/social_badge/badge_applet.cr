require "lvgl-crystal/src/lvgl"
require "./timeline_service"

module SocialBadge
  class BadgeApplet < Lvgl::Applet
    HEADER_Y       =         8
    STATUS_Y       =        30
    TIMELINE_START =        58
    TIMELINE_ROW_H =        30
    LOOP_UPDATE_MS = 5_000_u64
    TIMELINE_LIMIT =         6

    @timeline : TimelineService
    @header_label : Lvgl::Widgets::Label?
    @status_label : Lvgl::Widgets::Label?
    @rows : Array(Lvgl::Widgets::Label)
    @last_refresh_tick : UInt64

    def initialize(@timeline = TimelineService.new)
      @rows = [] of Lvgl::Widgets::Label
      @last_refresh_tick = 0_u64
    end

    def setup(screen : Lvgl::Object = Lvgl::Object.screen_active)
      screen.set_style_bg_color(Lvgl::Color.hex(0x0f172a), Lvgl::Part::Main)

      @header_label = Lvgl::Widgets::Label.new(screen)
      @header_label.not_nil!.text = "Social Badge"
      @header_label.not_nil!.set_style_text_color(Lvgl::Color.hex(0xe2e8f0), Lvgl::Part::Main)
      @header_label.not_nil!.set_pos(8, HEADER_Y)

      @status_label = Lvgl::Widgets::Label.new(screen)
      @status_label.not_nil!.set_style_text_color(Lvgl::Color.hex(0x93c5fd), Lvgl::Part::Main)
      @status_label.not_nil!.set_pos(8, STATUS_Y)

      TIMELINE_LIMIT.times do |idx|
        row = Lvgl::Widgets::Label.new(screen)
        row.set_style_text_color(Lvgl::Color.hex(0xf8fafc), Lvgl::Part::Main)
        row.set_pos(8, TIMELINE_START + (idx * TIMELINE_ROW_H))
        row.text = ""
        @rows << row
      end

      refresh_ui
    end

    def loop(screen : Lvgl::Object = Lvgl::Object.screen_active, message : Lvgl::Message = Lvgl::Message.new)
      return if message.tick_ms < @last_refresh_tick + LOOP_UPDATE_MS
      refresh_ui
      @last_refresh_tick = message.tick_ms
    end

    def cleanup(screen : Lvgl::Object = Lvgl::Object.screen_active)
      @rows.each(&.delete)
      @rows.clear
      @header_label.try(&.delete)
      @status_label.try(&.delete)
      @header_label = nil
      @status_label = nil
    end

    private def refresh_ui
      identity = @timeline.identity
      @status_label.try do |status|
        status.text = "#{identity.display_name} (#{identity.trust_level})"
      end

      messages = @timeline.timeline(TIMELINE_LIMIT)
      @rows.each_with_index do |row, idx|
        message = messages[idx]?
        row.text = message ? compact_row(message) : ""
      end
    end

    private def compact_row(message : Message) : String
      author = message.author_id.split(':').last? || message.author_id
      body = message.body.gsub(/\s+/, " ").strip
      body = body.size > 34 ? "#{body[0, 33]}…" : body
      "#{author}: #{body}"
    end
  end
end
