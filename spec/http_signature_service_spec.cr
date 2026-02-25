require "./spec_helper"
require "base64"
require "openssl"

module SocialBadge
  private def signed_request(
    key : OpenSSL::PKey::RSA,
    key_id : String,
    host : String = "example.com",
    body : String = "",
    include_digest : Bool = true,
  )
    request = HTTP::Request.new("POST", "/users/demo/inbox", body: body)
    request.headers["Host"] = host
    request.headers["Date"] = "Tue, 25 Feb 2026 00:00:00 GMT"
    if include_digest
      digest = Base64.strict_encode(OpenSSL::Digest.new("SHA256").digest(body))
      request.headers["Digest"] = "SHA-256=#{digest}"
    end

    signing_string = <<-TEXT
(request-target): post /users/demo/inbox
host: #{host}
date: Tue, 25 Feb 2026 00:00:00 GMT
digest: #{request.headers["Digest"]?}
TEXT

    signature = Base64.strict_encode(key.sign(OpenSSL::Digest.new("SHA256"), signing_string))
    request.headers["Signature"] =
      "keyId=\"#{key_id}\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date digest\",signature=\"#{signature}\""
    request
  end

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
      request = signed_request(key, config.public_key_id, body: "hello")

      result = service.verify(request)

      result.ok.should be_true
    end

    it "caches remote public keys within the TTL" do
      key = OpenSSL::PKey::RSA.new(2048)
      public_pem = key.public_key.to_pem
      key_id = "http://remote.example.com/users/alice#main-key"
      calls = 0
      fetcher = ->(requested_key_id : String) do
        calls += 1
        requested_key_id.should eq(key_id)
        public_pem
      end

      config = ActivityPubConfig.new(
        base_url: "http://example.com",
        actor_name: "demo",
        public_key_pem: "UNCONFIGURED",
        key_cache_ttl_seconds: 3600,
      )
      service = HttpSignatureService.new(config, key_fetcher: fetcher)
      request = signed_request(key, key_id, "remote.example.com", body: "payload")

      service.verify(request).ok.should be_true
      service.verify(request).ok.should be_true
      calls.should eq(1)
    end

    it "refreshes a remote key after verification failure" do
      correct_key = OpenSSL::PKey::RSA.new(2048)
      wrong_key = OpenSSL::PKey::RSA.new(2048)
      key_id = "http://remote.example.com/users/alice#main-key"
      calls = 0
      fetcher = ->(_requested_key_id : String) do
        calls += 1
        calls == 1 ? wrong_key.public_key.to_pem : correct_key.public_key.to_pem
      end

      config = ActivityPubConfig.new(
        base_url: "http://example.com",
        actor_name: "demo",
        public_key_pem: "UNCONFIGURED",
        key_cache_ttl_seconds: 3600,
      )
      service = HttpSignatureService.new(config, key_fetcher: fetcher)
      request = signed_request(correct_key, key_id, "remote.example.com", body: "payload")

      service.verify(request).ok.should be_true
      calls.should eq(2)
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

    it "rejects a missing digest header when signed" do
      key = OpenSSL::PKey::RSA.new(2048)
      config = ActivityPubConfig.new(
        base_url: "http://example.com",
        actor_name: "demo",
        public_key_pem: key.public_key.to_pem,
      )
      service = HttpSignatureService.new(config)
      request = signed_request(key, config.public_key_id, body: "hello", include_digest: false)

      result = service.verify(request)

      result.ok.should be_false
    end

    it "rejects a digest mismatch" do
      key = OpenSSL::PKey::RSA.new(2048)
      config = ActivityPubConfig.new(
        base_url: "http://example.com",
        actor_name: "demo",
        public_key_pem: key.public_key.to_pem,
      )
      service = HttpSignatureService.new(config)
      request = signed_request(key, config.public_key_id, body: "hello")
      request.body = IO::Memory.new("tampered")

      result = service.verify(request)

      result.ok.should be_false
    end
  end
end
