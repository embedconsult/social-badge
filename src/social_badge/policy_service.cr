require "json"

module SocialBadge
  struct TrustPolicy
    include JSON::Serializable

    getter downgrade_interval_days : Int32
    getter revocation_ttl_days : Int32
    getter local_approval_required : Bool

    def initialize(
      @downgrade_interval_days : Int32 = 30,
      @revocation_ttl_days : Int32 = 7,
      @local_approval_required : Bool = true,
    )
    end
  end

  struct InputPolicy
    include JSON::Serializable

    getter usb_keyboard_web_admin_enabled : Bool
    getter usb_keyboard_badge_authoring_enabled : Bool
    getter browse_first_badge_navigation : Bool
    getter on_screen_keyboard_enabled : Bool

    def initialize(
      @usb_keyboard_web_admin_enabled : Bool = true,
      @usb_keyboard_badge_authoring_enabled : Bool = true,
      @browse_first_badge_navigation : Bool = true,
      @on_screen_keyboard_enabled : Bool = false,
    )
    end
  end

  class PolicyService
    getter trust_policy : TrustPolicy
    getter input_policy : InputPolicy

    def initialize(
      @trust_policy : TrustPolicy = TrustPolicy.new,
      @input_policy : InputPolicy = InputPolicy.new,
    )
    end
  end
end
