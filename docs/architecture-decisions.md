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

USB keyboard input is also explicitly enabled for both web administration and badge-local
authoring screens. The badge interaction model remains browse-first by default, but this keeps
v1 composition practical without requiring an on-screen keyboard.

## V1 policy defaults are exposed as API resources

`PolicyService` centralizes fixed v1 trust and input defaults in one composable service object.
Kemal exposes these via machine-readable JSON endpoints:

- `GET /api/policy/trust`
- `GET /api/policy/input`

This keeps route handlers concise while making operational defaults discoverable to both
badge and web clients without duplicating constants across UI code.
