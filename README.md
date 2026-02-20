# social-badge

Initial Crystal scaffold for the Social Badge peer node.

## What is included

- Crystal project layout compatible with `crystal init` conventions.
- Kemal-based HTTP shell with health, profile, and timeline endpoints.
- Browser composer at `/` with live 320x240 message preview, richer markdown,
  message-defined font directives, Typst-style directives, and embedded QR artifacts
  for URL/event/contact content.
- A small in-memory domain service for posting Meshtastic-friendly messages.
- Canonical Meshtastic envelope projection and HTTP peer relay queue/retry endpoints.
- Explicit JSON request models for API payload validation.
- Project-level `AGENTS.md` with coding workflow guidance.
- Typst layout package + Crystal bit-exact PNG fixture checker.

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

## Run (when Crystal is available)

```bash
shards install
crystal run src/main.cr
```

Then visit `http://127.0.0.1:3000/health`.
