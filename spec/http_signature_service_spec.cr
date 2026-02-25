require "./spec_helper"
require "openssl"

module SocialBadge
  describe HttpSignatureService do
    it "verifies a valid RSA-SHA256 signature" do
      key = OpenSSL::PKey::RSA.new(2048)
      public_pem = key.public_key.to_pem

      config = ActivityPubConfig.new(
        base_url: "http://example.com",
        actor_name: "demo",
        public_key_pem: public_pem,
      )

      service = HttpSignatureService.new(config)

      request = HTTP::Request.new("POST", "/users/demo/inbox")
      request.headers["Host"] = "example.com"
      request.headers["Date"] = "Tue, 25 Feb 2026 00:00:00 GMT"

      signing_string = <<-TEXT
(request-target): post /users/demo/inbox
host: example.com
date: Tue, 25 Feb 2026 00:00:00 GMT
TEXT

      signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signing_string))
      request.headers["Signature"] =
        "keyId=\"#{config.public_key_id}\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date\",signature=\"#{signature}\""

      result = service.verify(request)

      result.ok.should be_true
    end

    it "rejects missing signatures by default" do
      service = HttpSignatureService.new(ActivityPubConfig.new)
      request = HTTP::Request.new("POST", "/users/demo/inbox")

      result = service.verify(request)

      result.ok.should be_false
    end

    it "allows missing signatures when configured" do
      config = ActivityPubConfig.new
      service = HttpSignatureService.new(config, allow_unsigned: true)
      request = HTTP::Request.new("POST", "/users/demo/inbox")

      result = service.verify(request)

      result.ok.should be_true
    end
  end
end
