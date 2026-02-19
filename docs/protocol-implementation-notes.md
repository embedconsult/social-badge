# Protocol Implementation Notes (v1)

## ActivityPub + WebFinger: what v1 needs

### Normative references

- ActivityPub (W3C Recommendation): https://www.w3.org/TR/activitypub/
- WebFinger (RFC 7033): https://datatracker.ietf.org/doc/html/rfc7033
- JSON Resource Descriptor (RFC 6415): https://datatracker.ietf.org/doc/html/rfc6415
- Mastodon implementation requirements (practical interop): https://docs.joinmastodon.org/spec/activitypub/

### Required server endpoints

1. `GET /.well-known/webfinger?resource=acct:<name>@<domain>`
2. `GET /users/:name` (actor document)
3. `POST /users/:name/inbox`
4. `GET /users/:name/outbox`

### Required response shapes

1. WebFinger returns `application/jrd+json` with:
- `subject: "acct:<name>@<domain>"`
- a `links` entry where `rel` is `self`, `type` is `application/activity+json`, and `href` points to actor URL.

2. Actor JSON includes stable IDs and key fields used by Mastodon interop:
- `id`, `type: "Person"`, `preferredUsername`, `inbox`, `outbox`, `publicKey`.

3. Inbox accepts ActivityStreams activities at minimum for v1:
- `Create` with embedded `Note` objects.

4. Outbox exposes authored activities (newest first), with stable IDs and timestamps.

### Delivery and security expectations

1. Serve ActivityPub resources as ActivityStreams JSON (`application/activity+json`) and support standard `Accept` negotiation.
2. Verify HTTP Signatures for signed inbox deliveries and include signatures for outbound federation requests (Mastodon requires this in practice).
3. Keep object IDs globally unique and stable URLs.
4. Deduplicate by activity/object ID to avoid replay loops.

### Implementation checklist for this repo

1. Add service objects:
- `WebFingerService`
- `ActivityPubActorService`
- `ActivityPubInboxService`
- `ActivityPubOutboxService`
- `HttpSignatureService`

2. Keep Kemal routes thin and JSON-only for API paths.

3. Add request/response models for:
- WebFinger JRD documents
- Actor documents
- `Create`/`Note` activities

4. Add tests for:
- WebFinger subject/link correctness
- actor field completeness
- signed inbox acceptance and invalid-signature rejection
- duplicate activity rejection

## Meshtastic: what v1 needs

### Normative references

- Meshtastic protocol buffers (source of wire constraints): https://github.com/meshtastic/protobufs
- `mesh.options` payload limits (`Data.payload`): https://github.com/meshtastic/protobufs/blob/master/meshtastic/mesh.options
- Meshtastic MQTT integration (gateway bridge behavior): https://meshtastic.org/docs/software/integrations/mqtt/

### Payload/metadata constraints

1. `Data.payload` max length is defined as `233` bytes in `mesh.options`.
2. Keep canonical message text short and compact metadata small to remain relay-friendly.
3. Use deterministic dedupe keys and message IDs to suppress rebroadcast loops.
4. Keep relay hop metadata bounded (`relay_hops` already constrained in code).

### Bridge/relay behavior for v1

1. Treat the Meshtastic envelope as canonical for peer transport.
2. On inbound mesh message:
- parse envelope
- validate limits
- dedupe by message ID and dedupe key
- store once

3. On outbound relay:
- enqueue with retry/backoff
- mark delivered/failed explicitly
- avoid auto-expanding payload fields that threaten mesh limits

4. For a public web node with mesh bridge:
- map mesh channel traffic to public timeline policy rules
- never assume all mesh messages are public by default

### Implementation checklist for this repo

1. Add Meshtastic adapter boundary object around protobuf encode/decode.
2. Add serialization tests proving encoded payloads remain within configured byte budget.
3. Add end-to-end tests for dedupe and retry transitions between inbox and outbound queue.
