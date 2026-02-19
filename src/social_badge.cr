require "./social_badge/version"
require "./social_badge/models"
require "./social_badge/timeline_service"
require "./social_badge/message_creation_service"
require "./social_badge/policy_service"
require "./social_badge/web_app"

module SocialBadge
  def self.boot
    app = WebApp.new
    app.routes
  end
end
