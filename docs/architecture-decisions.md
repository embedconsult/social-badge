# Architecture decisions

## API payloads are explicit JSON models

`POST /api/messages` now deserializes into `CreateMessageRequest` instead of a generic hash.
This keeps the route machine-readable with consistent 422 JSON failures when body fields are
missing or malformed, and keeps endpoint logic compact.

Parsing and message creation are delegated to `MessageCreationService`, so route handlers remain
small and focused on HTTP concerns while domain validation continues in `TimelineService`.
The service normalizes parse/shape failures to compact, stable error strings so API clients can
rely on consistent machine-readable 422 responses.

## Keep runtime dependencies minimal

The project currently uses Kemal as its only direct shard dependency. Additional UI/database
shards were removed because they were not used by the current API-first implementation.
This keeps setup simple for peer-node deployments.

## V1 trust and input defaults are fixed

To remove ambiguity from v1 delivery planning, two operational defaults are now fixed:

- identity trust downgrade interval defaults to 30 days without renewal;
- revocation propagation TTL defaults to 7 days over peer channels.

USB keyboard input is enabled for badge-local authoring screens only. Web interaction remains
web-interface driven and does not model direct keyboard attachment as an app-level input mode.
The badge interaction model remains browse-first by default, which keeps v1 composition practical
without requiring an on-screen keyboard.

## V1 trust defaults are exposed as API resources

`PolicyService` centralizes fixed v1 trust defaults in one composable service object.
Kemal exposes this via a machine-readable JSON endpoint:

- `GET /api/policy/trust`

This keeps route handlers concise while making operational defaults discoverable to clients
without duplicating constants across UI code.

## Meshtastic envelopes are canonical for peer relay

`MeshtasticEnvelopeService` projects timeline messages into compact envelopes with explicit
dedupe keys, trust level, and relay-hop metadata. The envelope model enforces v1 guardrails
for payload/body size and compact metadata lengths so peer transport always uses
Meshtastic-friendly representations.

## Peer relay baseline uses explicit queue + retry state

`PeerTransportService` owns outbound relay queue state, exponential retry backoff, and inbound
peer envelope ingestion. `PeerRelayService` keeps HTTP parsing concerns separate from transport
state transitions. Kemal exposes this baseline via JSON endpoints for enqueueing relay jobs,
inspecting queue state, marking delivery outcomes, and accepting inbound envelopes.

## Web typesetting is canonical; badge consumes rendered image artifacts

For the `MSG_320x240` viewport, browser layout behavior is the canonical typesetting reference.
The badge LVGL path should consume deterministic `320x240` image artifacts produced from the same
layout contract, while web output preserves selectable/copyable text. Trust indicators stay in
chrome only and never alter message body content.

## Authoring preview supports structured QR artifacts

The web composer recognizes URLs and Typst-style directives (`#place(...)`,
`#font(...)`, `#qr(...)`, `#event(...)`, `#contact(...)`) as artifact/layout controls.
Typst directives are non-printing in the body layout so control syntax does not
consume message viewport lines. Inline artifact placement defaults to right-float
and can be explicitly set with `#place("right"|"left"|"top"|"bottom"|"none")`.
Font selection is message-defined via short IDs to keep rendering inputs fully
self-contained in the message payload. Rendering uses a hard single-page 320x240
limit with no pagination fallback; overflow must be corrected at author time.

## Typst package is the fixture renderer for bit-exact layout tests

`typst/social-badge/layout.typ` defines the deterministic 400x300 + 320x240
geometry contract used for fixture rendering. `scripts/check_typst_layouts.cr`
compiles cases from `testdata/typst/layout_cases.json` to PNG and verifies
SHA-256 hashes for bit-exact regression checks. This keeps layout validation
machine-checkable while the browser preview evolves.
