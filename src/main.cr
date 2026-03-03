require "./social_badge"
require "./social_badge/badge_applet"
require "kemal"

# Prevent lvgl-crystal autorun at process exit; we start the loop explicitly.
ENV["LVGL_NO_AUTORUN"] = "1"

# Default to headless when no local UI backend is declared.
unless ENV["SOCIAL_BADGE_LOCAL_UI"]? == "1" || ENV["LVGL_BACKEND"]?
  ENV["LVGL_BACKEND"] = "headless"
end

SocialBadge.boot

spawn do
  Kemal.run 30000
end

exit Lvgl.main
