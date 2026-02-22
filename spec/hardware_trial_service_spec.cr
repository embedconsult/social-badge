require "json"
require "./spec_helper"

describe SocialBadge::HardwareTrialService do
  it "returns a Meshtastic-scoped checklist with stable IDs" do
    service = SocialBadge::HardwareTrialService.new

    service.protocol_scope.should contain("Meshtastic")
    service.caution.should contain("LoRaWAN")
    service.checklist.map(&.id).should eq([
      "payload-budget",
      "dedupe-replay",
      "retry-backoff",
      "bridge-policy",
      "e2e-success",
    ])
  end

  it "serializes checklist as machine-readable json" do
    service = SocialBadge::HardwareTrialService.new
    payload = JSON.parse(service.as_json)

    payload["checklist"].as_a.size.should eq(5)
    payload["checklist"][0]["category"].as_s.should eq("encoding")
  end
end
