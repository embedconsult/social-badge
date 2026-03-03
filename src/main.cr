require "./social_badge"
require "./social_badge/badge_applet"
require "kemal"

runtime = ENV["SOCIAL_BADGE_RUNTIME"]? || "web"

if runtime == "badge_ui"
  SocialBadge::BadgeApplet.new
  exit Lvgl.main
end

SocialBadge.boot
Kemal.run 30000
