# Repository Agent Instructions

## Scope
These instructions apply to the entire repository.

## Project expectations
- Keep all code in Crystal.
- Prefer lightweight, dependency-minimal implementations.
- Keep message models Meshtastic-friendly (short text defaults, compact metadata).

## Workflow
- Add or update docs for notable architecture decisions.
- Prefer small, composable service objects over monolithic route handlers.
- Ensure HTTP endpoints return machine-readable JSON for API routes.

## Validation
- Run formatting and tests whenever Crystal tooling is available.
- If Crystal toolchain is unavailable, document the limitation in your final summary.
