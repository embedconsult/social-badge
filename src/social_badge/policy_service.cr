require "json"

module SocialBadge
  # Fixed v1 trust defaults. These are read-only policy values, not user-tunable
  # runtime settings in this repository.
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

  class PolicyService
    getter trust_policy : TrustPolicy

    def initialize(
      @trust_policy : TrustPolicy = TrustPolicy.new,
    )
    end
  end
end
