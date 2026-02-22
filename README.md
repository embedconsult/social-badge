# social-badge

Initial Crystal scaffold for the Social Badge peer node.

## What is included

- Crystal project layout compatible with `crystal init` conventions.
- Kemal-based HTTP shell with health, profile, and timeline endpoints.
- Browser composer at `/` with live server-rendered Typst `320x240` preview,
  message-defined font directives, Typst-style placement directives, and QR/event/
  contact controls rendered through local Typst packages.
- A small in-memory domain service for posting Meshtastic-friendly messages.
- Canonical Meshtastic envelope projection, compact payload encoding, and HTTP peer relay queue/retry endpoints.
- Meshtastic payload handoff endpoints for base64-encoded radio frames (`/api/peer/inbox_payload` and outbound payload export).
- Machine-readable Meshtastic hardware-trial checklist endpoint for real radio validation planning.
- Explicit JSON request models for API payload validation.
- Project-level `AGENTS.md` with coding workflow guidance.
- Typst message-window layout package + Crystal bit-exact PNG fixture checker.

See `docs/architecture-decisions.md` for implementation rationale.
See `docs/protocol-implementation-notes.md` for ActivityPub/WebFinger and Meshtastic
implementation requirements.
See `docs/message-rendering-320x240.md` for v1 message formatting requirements for
the badge `320x240` message viewport, including browser-canonical typesetting
and badge image artifact output.
See `docs/typst-layout-tests.md` for Typst package usage and the bit-exact
layout regression workflow.
See `docs/open-font-profiles.md` for open font profile IDs used across preview
and badge targets.
See `docs/typst-runtime.md` for Typst runtime requirements and Debian/Ubuntu
installation options.

## Run (when Crystal is available)

```bash
shards install
crystal run src/main.cr
```

Then visit `http://127.0.0.1:30000/health`.
