require "base64"
require "http/client"
require "json"
require "openssl"
require "uri"
require "./activitypub_config"

module SocialBadge
  class HttpSignatureService
    struct VerificationResult
      getter ok : Bool
      getter error : String?

      def initialize(@ok : Bool, @error : String? = nil)
      end
    end

    private struct SignatureHeader
      getter key_id : String
      getter algorithm : String
      getter headers : Array(String)
      getter signature_b64 : String

      def initialize(
        @key_id : String,
        @algorithm : String,
        @headers : Array(String),
        @signature_b64 : String,
      )
      end
    end

    private struct CachedKey
      getter pem : String
      getter fetched_at : Time

      def initialize(@pem : String, @fetched_at : Time = Time.utc)
      end
    end

    def initialize(
      @config : ActivityPubConfig = ActivityPubConfig.new,
      @allow_unsigned : Bool = @config.allow_unsigned,
      @skip_verify : Bool = @config.skip_signature_verify,
      @key_fetcher : Proc(String, String)? = nil,
    )
      @key_cache = {} of String => CachedKey
    end

    def verify(request : HTTP::Request) : VerificationResult
      signature_header = request.headers["Signature"]?
      if signature_header.nil?
        return VerificationResult.new(true) if @allow_unsigned
        return VerificationResult.new(false, "Missing HTTP Signature")
      end

      return VerificationResult.new(true) if @skip_verify

      parsed = parse_signature(signature_header)
      signing_string = build_signing_string(parsed.headers, request)

      algorithm = parsed.algorithm.downcase
      unless algorithm == "rsa-sha256" || algorithm == "hs2019"
        return VerificationResult.new(false, "Unsupported HTTP Signature algorithm")
      end

      signature = Base64.decode(parsed.signature_b64)
      digest = OpenSSL::Digest.new("SHA256")

      verified = verify_with_key(parsed.key_id, signature, signing_string, digest, force_refresh: false)
      return VerificationResult.new(true) if verified

      if local_key_id?(parsed.key_id)
        return VerificationResult.new(false, "Invalid HTTP Signature")
      end

      verified = verify_with_key(parsed.key_id, signature, signing_string, digest, force_refresh: true)
      return VerificationResult.new(true) if verified

      VerificationResult.new(false, "Invalid HTTP Signature")
    rescue ex : ArgumentError
      VerificationResult.new(false, ex.message)
    rescue ex
      VerificationResult.new(false, "HTTP Signature verification failed")
    end

    private def parse_signature(header : String) : SignatureHeader
      parts = header.split(",").map(&.strip)
      fields = {} of String => String
      parts.each do |part|
        key, value = part.split("=", 2)
        next unless key && value
        value = value.strip
        value = value[1..-2] if value.starts_with?("\"") && value.ends_with?("\"")
        fields[key.strip] = value
      end

      key_id = fields["keyId"]? || raise ArgumentError.new("Missing keyId in Signature header")
      signature_b64 = fields["signature"]? || raise ArgumentError.new("Missing signature in Signature header")
      algorithm = fields["algorithm"]? || "rsa-sha256"
      headers_field = fields["headers"]? || "(request-target)"
      headers = headers_field.split(" ").map(&.strip).reject(&.empty?)

      SignatureHeader.new(
        key_id: key_id,
        algorithm: algorithm,
        headers: headers,
        signature_b64: signature_b64,
      )
    end

    private def build_signing_string(headers : Array(String), request : HTTP::Request) : String
      lines = headers.map do |header|
        if header == "(request-target)"
          method = request.method.to_s.downcase
          target = request.resource
          "(request-target): #{method} #{target}"
        else
          value = request.headers[header]?
          raise ArgumentError.new("Missing signed header: #{header}") unless value
          "#{header.downcase}: #{value}"
        end
      end
      lines.join("\n")
    end

    private def verify_with_key(
      key_id : String,
      signature : Bytes,
      signing_string : String,
      digest : OpenSSL::Digest,
      force_refresh : Bool,
    ) : Bool
      public_key_pem = resolve_public_key(key_id, force_refresh)
      public_key = OpenSSL::PKey::RSA.new(public_key_pem)
      public_key.verify(digest, signature, signing_string)
    end

    private def local_key_id?(key_id : String) : Bool
      key_id == @config.public_key_id
    end

    private def resolve_public_key(key_id : String, force_refresh : Bool) : String
      return @config.public_key_pem if local_key_id?(key_id)

      cached = @key_cache[key_id]?
      ttl = @config.key_cache_ttl_seconds
      if !force_refresh && cached && ttl > 0
        age = Time.utc - cached.fetched_at
        return cached.pem if age.total_seconds <= ttl
      end

      public_key_pem = fetch_public_key(key_id)
      @key_cache[key_id] = CachedKey.new(public_key_pem)
      public_key_pem
    rescue URI::Error
      raise ArgumentError.new("Invalid keyId URL")
    end

    private def fetch_public_key(key_id : String) : String
      if @key_fetcher
        return @key_fetcher.not_nil!.call(key_id)
      end

      uri = URI.parse(key_id)
      client = HTTP::Client.new(uri)
      request = HTTP::Request.new("GET", uri.request_target)
      request.headers["Accept"] = "application/activity+json"
      response = client.exec(request)
      raise ArgumentError.new("Failed to fetch public key") unless response.status_code.between?(200, 299)

      payload = JSON.parse(response.body)
      public_key = payload["publicKey"]? || raise ArgumentError.new("Missing publicKey in actor")
      public_key_pem = public_key["publicKeyPem"]?.try(&.as_s?) || raise ArgumentError.new("Missing publicKeyPem")
      public_key_pem
    rescue URI::Error
      raise ArgumentError.new("Invalid keyId URL")
    end
  end
end
