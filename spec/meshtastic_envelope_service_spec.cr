require "./spec_helper"

describe SocialBadge::MeshtasticEnvelopeService do
  it "builds compact envelope metadata from a message" do
    service = SocialBadge::MeshtasticEnvelopeService.new
    message = SocialBadge::Message.new(
      id: "msg-1",
      author_id: "oidc:forum.beagleboard.org:demo",
      body: "hello mesh",
      created_at: Time.unix_ms(1_735_000_000_000_i64)
    )

    envelope = service.build_from(message, SocialBadge::TrustLevel::Unverified)

    envelope.message_id.should eq("msg-1")
    envelope.body.should eq("hello mesh")
    envelope.origin.should eq("local")
    envelope.dedupe_key.size.should eq(32)
  end

  it "validates envelope payload constraints" do
    expect_raises(ArgumentError, /relay hops/) do
      SocialBadge::MeshtasticEnvelope.new(
        message_id: "msg-1",
        author_id: "peer:demo",
        body: "hi",
        created_at_unix_ms: Time.utc.to_unix_ms,
        trust_level: SocialBadge::TrustLevel::PeerAttested,
        dedupe_key: "abc",
        origin: "peer",
        relay_hops: 8
      )
    end
  end
end
