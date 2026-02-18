# Social Badge Crystal App — Initial Project Brief

## Product Vision
Build a **single Crystal codebase** that operates as both:
1. A local-first peer node (client + server responsibilities), and
2. A web-enabled social endpoint that can federate over ActivityPub-compatible protocols (including Mastodon interoperability) and relay concise messages over Meshtastic.

The device experience uses a **400x300 full local badge UI**, with message content rendered to a **320x240 e-paper content region** inside that UI.

## Core Requirements Captured
- Language/runtime: **pure Crystal**.
- Web framework/server: **Kemal**.
- Embedded/device UI toolkit: **Crystal-LVGL**.
- Federation: **full standalone ActivityPub-compatible federation** (inbox/outbox, actors, WebFinger, HTTP Signatures), interoperable with Mastodon but not dependent on it.
- Radio/off-grid propagation: **Meshtastic-first message path**, with all authored content constrained to Meshtastic-friendly payload semantics.
- Unified peer model: one app role that can both publish and consume content.
- Hardware controls:
  - one 4-way button with push,
  - dedicated back button,
  - dedicated select button,
  - RGB LED for notification states,
  - 2-digit 7-segment LED for counters.
- Authoring:
  - richer composition on web interface,
  - constrained authoring/browsing on badge UI.

## Proposed High-Level Architecture
### 1) Core domain layer (shared)
- Message model, author identity, timeline, reactions/minimal interactions.
- Serialization adapters for:
  - ActivityPub/Mastodon wire format.
  - Meshtastic payload envelopes (compact).
- Conflict + dedupe strategy for peer propagation (ID + vector-like metadata or lamport time).

### 2) Transport layer
- **HTTP/Kemal transport** for web + federation.
- **Meshtastic transport adapter** for nearby/off-grid propagation.
- Inbound messages are normalized into domain events regardless of origin.

### 3) Persistence layer
- Local store (SQLite preferred initially) for:
  - identities/keys,
  - posts/messages,
  - sync state,
  - outbound retry queue.
- Resource envelope target for v1 runtime + data:
  - **Disk budget:** 2 GB available.
  - **Memory budget:** 128 MB available.

### 4) UI layer
- **Badge UI (Crystal-LVGL)** for quick read/respond triage, notifications, counts.
- **Web UI (Kemal + templates/API)** should mimic the badge-local LVGL interface and extend it with richer composition/edit/administration.
- Shared application services to keep behavior consistent across both UIs.

### 5) Device integration layer
- Input manager mapping hardware controls to semantic actions.
- Output manager for RGB LED + 7-seg count display.
- Notification policy engine (priority/event-type -> LED color/pattern + count update).

## Display Profile Strategy
To align with one local UI resolution and a dedicated message viewport:
- Define a single local screen profile: `BADGE_400x300`.
- Reserve a message-rendering viewport: `MSG_320x240` within the 400x300 layout.
- Use LVGL layout containers to keep navigation/status chrome outside the message viewport.
- Keep the interaction model identical between web and badge, while constraining badge composition controls.

## Message Format & Rendering Profile (confirmed)
- Keep **all messages Meshtastic-friendly** as the canonical content model.
- Use an **extended markdown dialect** for authored content so rich formatting can still render well in the `MSG_320x240` window.
- Require strong **UTF-8 coverage** and mixed font sizing/weight support for readable compact layouts.
- Include a robust emoji set plus **Font Awesome-style icon extensions** for compact visual semantics.
- Support **QR code generation** from message content/metadata for quick handoff flows.
- Allow small embedded **base64 PNG** images (grayscale/black-and-white) for v1, within strict payload limits.
- Allow **image URLs** as references for pull-on-demand media instead of embedding heavy payloads in mesh messages.
- Treat SVG as optional and constrained: prefer icon-level vector support, but avoid large inline SVG payloads that hurt Meshtastic message size budgets.

## Milestone Sketch
1. Bootstrap Crystal project + Kemal + Crystal-LVGL integration shell.
2. Implement local timeline + posting in web UI.
3. Add badge UI navigation and message viewing.
4. Add full standalone ActivityPub federation pipeline (with Mastodon interoperability).
5. Add Meshtastic relay adapter + canonical meshtastic-friendly extended-markdown projection.
6. Hardware feedback (RGB/7-seg) and control bindings.
7. End-to-end peer sync, offline/online transitions, and durability hardening.

## Confirmed Decisions (from latest feedback)
1. **Peer model and independence:** every instance must be fully stand-alone and functional without depending on Mastodon as an external service.
2. **Topology:** all instances operate as peers; additionally, at least one instance should run on a fixed domain as a default/shared out-of-the-box message source.
3. **Account source:** no local account provider in this app. For v1, use **Discourse** as the identity/account authority via `forum.beagleboard.org`.
4. **Login standard preference:** use an open standard-based login flow, preferably **OpenID Connect (OIDC)**.
5. **Message constraints:** all authored messages should remain Meshtastic-friendly while supporting rich rendering via extended markdown, UTF-8, emojis/icons, QR generation, and URL-based media references.
6. **Identity model:** use a single primary identity rooted in OpenID Connect; add offline-capable peer-signature attestations on Meshtastic to provide graded trust when direct OIDC validation is unavailable.
7. **Storage constraints:** design for 2 GB disk and 128 MB memory available to the full application.
8. **Media handling for v1:** allow small embedded **base64 PNG** payloads for grayscale or black-and-white images, while keeping richer/larger media URL-referenced to remain Meshtastic-friendly.

## Identity Trust & Verification Model (confirmed)
- Maintain **one canonical user identity** anchored to OIDC-authenticated account claims.
- Support **offline Meshtastic identity assertions** signed by trusted peers.
- Represent identity assurance with explicit trust levels, for example:
  - `FULL_OIDC_VERIFIED`: directly validated via OIDC provider.
  - `PEER_ATTESTED`: validated indirectly through one or more trusted peer signatures.
  - `UNVERIFIED`: no trusted proof currently available.
- Implement a simple **web-of-trust extension** where trust can be delegated from known peers to identity attestations they sign.
- Ensure the UI clearly indicates assurance level so users can distinguish direct OIDC verification from proxy/peer-based verification.
- Local trust actions must always be user-approved; trust is never auto-granted.
- Trust prompt metadata should explicitly distinguish: direct OIDC verification, trusted-peer attestation, untrusted-but-OIDC-verified peer attestation, and untrusted-and-unverified peer attestation.
- Apply a default trust-downgrade period and propagate revocations across peers, but do not perform automated actions beyond trust-level downgrades.

## Confirmed Decisions (additional)
9. **Security policy detail:** all trust elevation requires explicit local-user trust action. Trust prompts must show identity proof source and attestation quality; include downgrade timers and propagated revocation handling, with no automated actions beyond lowering trust levels.
10. **Badge input UX:** 4-way+push is browse-first with canned replies. Support optional USB keyboard for richer entry, with no on-screen keyboard. Emoji/tapback/Font Awesome response inputs should be preference-controlled.
11. **Notification behavior:** user preferences map system events to RGB LED colors/patterns. Provide stock mappings plus an extensible Crystal-block execution model in a notification fiber. Persist preferences in JSON and include event sources for mention, DM, relay failure, and battery/network warnings.
12. **2-digit 7-seg behavior:** display meaning is preference-driven and tied to system-state notifications (e.g., unread, mentions, queued outbound, errors).
13. **Deployment topology:** each badge is its own peer with web administration. Multi-instance per user is allowed, but settings remain per-instance (not globally synced). Instances should exchange trust context and consume peer messages under the shared established identity.
14. **Kemal web interface:** should mimic badge-local LVGL interaction patterns and extend capabilities where appropriate.
15. **Success criteria for v1:** two badges exchange posts over Meshtastic, a public web server displays and forwards public posts, and federation posts are visible on Mastodon.

## Clarifying Questions
1. **Attestation policy defaults:** what exact default downgrade interval and revocation TTL should v1 ship with?
2. **USB keyboard scope:** should USB keyboard entry be allowed only in web-admin mode or also directly on badge-local authoring screens?
