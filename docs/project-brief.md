# Social Badge Crystal App — Initial Project Brief

## Product Vision
Build a **single Crystal codebase** that operates as both:
1. A local-first peer node (client + server responsibilities), and
2. A web-enabled social endpoint that can federate over Mastodon-compatible protocols and relay concise messages over Meshtastic.

The device experience targets e-paper rendering at **320x280** while also supporting a **400x300 badge UI mode** for constrained interactions.

## Core Requirements Captured
- Language/runtime: **pure Crystal**.
- Web framework/server: **Kemal**.
- Embedded/device UI toolkit: **Crystal-LVGL**.
- Federation: **Mastodon-compatible federation** (likely ActivityPub + WebFinger + HTTP Signatures ecosystem).
- Radio/off-grid propagation: **Meshtastic** message path.
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

### 4) UI layer
- **Badge UI (Crystal-LVGL)** for quick read/respond triage, notifications, counts.
- **Web UI (Kemal + templates/API)** for richer composition/edit/administration.
- Shared application services to keep behavior consistent across both UIs.

### 5) Device integration layer
- Input manager mapping hardware controls to semantic actions.
- Output manager for RGB LED + 7-seg count display.
- Notification policy engine (priority/event-type -> LED color/pattern + count update).

## Display Profile Strategy
To reconcile dual dimensions (**320x280 e-paper** and **400x300 badge UI**):
- Define screen profiles:
  - `EPD_320x280` (primary rendering constraints).
  - `BADGE_400x300` (enhanced layout if available).
- Use responsive LVGL layout containers and typography scaling rules.
- Keep interaction model identical, vary density only.

## Milestone Sketch
1. Bootstrap Crystal project + Kemal + Crystal-LVGL integration shell.
2. Implement local timeline + posting in web UI.
3. Add badge UI navigation and message viewing.
4. Add ActivityPub/Mastodon federation pipeline.
5. Add Meshtastic relay adapter + compact message projection.
6. Hardware feedback (RGB/7-seg) and control bindings.
7. End-to-end peer sync, offline/online transitions, and durability hardening.

## Clarifying Questions
1. **Federation scope:** do you want full ActivityPub server compatibility (inbox/outbox, actors, signatures), or initially Mastodon-oriented interoperability for posting/following only?
2. **Meshtastic semantics:** should all posts be relayed over Meshtastic, or only selected low-bandwidth message types (e.g., short text/status/alerts)?
3. **Identity model:** one identity shared across web + badge + mesh, or separate local/mesh personas bridged by the app?
4. **Storage constraints:** any expected disk/RAM limits on target hardware that should constrain retention, indexing, and media support?
5. **Media handling:** text-only v1, or images/attachments required for web and downsampled previews for badge?
6. **Security model:** should peer links be trusted-local only initially, or require cryptographic verification/signing from day one across both federation and mesh?
7. **Badge input UX:** should 4-way+push focus on browse actions with canned replies, or do you want full text entry on-device (e.g., multi-tap/selector keyboard)?
8. **Notification behavior:** what event classes map to RGB LED colors/patterns (mention, DM, relay failure, battery/network warning)?
9. **2-digit 7-seg meaning:** unread count only, or mode-dependent count (mentions, queued outbound, errors)?
10. **Deployment topology:** single peer per badge with optional web administration, or multi-peer cluster syncing a shared account?
11. **Kemal web interface:** server-rendered HTML only for v1, or JSON API + JS front-end also needed?
12. **Success criteria for v1:** what exact “done” scenario should we optimize for (e.g., two badges exchanging posts over mesh + visible federation post on Mastodon)?
