require "./spec_helper"

describe SocialBadge::MeshtasticAdapterService do
  it "encodes and decodes envelope payloads within byte budget" do
    adapter = SocialBadge::MeshtasticAdapterService.new
    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "m1",
      author_id: "peer:1",
      body: "mesh hello",
      created_at_unix_ms: 1_735_000_000_000_i64,
      trust_level: SocialBadge::TrustLevel::PeerAttested,
      dedupe_key: "0123456789abcdef0123456789abcdef",
      origin: "peer",
      relay_hops: 1
    )

    encoded = adapter.encode(envelope)
    encoded.size.should be <= SocialBadge::MeshtasticAdapterService::MAX_PAYLOAD_BYTES

    decoded = adapter.decode(encoded)
    decoded.message_id.should eq("m1")
    decoded.body.should eq("mesh hello")
    decoded.trust_level.should eq(SocialBadge::TrustLevel::PeerAttested)
  end

  it "rejects oversized encoded payloads" do
    adapter = SocialBadge::MeshtasticAdapterService.new
    long_body = "x" * 280

    envelope = SocialBadge::MeshtasticEnvelope.new(
      message_id: "m2",
      author_id: "peer:2",
      body: long_body,
      created_at_unix_ms: 1_735_000_000_000_i64,
      trust_level: SocialBadge::TrustLevel::Unverified,
      dedupe_key: "fedcba9876543210fedcba9876543210",
      origin: "local",
      relay_hops: 0
    )

    expect_raises(ArgumentError, /exceeds 233/) do
      adapter.encode(envelope)
    end
  end
end
