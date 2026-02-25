module SocialBadge
  class HttpSignatureService
    struct VerificationResult
      getter ok : Bool
      getter error : String?

      def initialize(@ok : Bool, @error : String? = nil)
      end
    end

    def initialize(
      @allow_unsigned : Bool = (ENV["SOCIAL_BADGE_ALLOW_UNSIGNED_AP"]? || "false") == "true",
      @skip_verify : Bool = (ENV["SOCIAL_BADGE_SKIP_SIGNATURE_VERIFY"]? || "false") == "true",
    )
    end

    def verify(request : HTTP::Request) : VerificationResult
      signature = request.headers["Signature"]?
      if signature
        return VerificationResult.new(true) if @skip_verify
        return VerificationResult.new(false, "HTTP Signature verification not configured")
      end

      return VerificationResult.new(true) if @allow_unsigned
      VerificationResult.new(false, "Missing HTTP Signature")
    end
  end
end
