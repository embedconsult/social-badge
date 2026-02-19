# social-badge

Initial Crystal scaffold for the Social Badge peer node.

## What is included

- Crystal project layout compatible with `crystal init` conventions.
- Kemal-based HTTP shell with health, profile, and timeline endpoints.
- A small in-memory domain service for posting Meshtastic-friendly messages.
- Explicit JSON request models for API payload validation.
- Project-level `AGENTS.md` with coding workflow guidance.

See `docs/architecture-decisions.md` for implementation rationale.

## Run (when Crystal is available)

```bash
shards install
crystal run src/main.cr
```

Then visit `http://127.0.0.1:3000/health`.
