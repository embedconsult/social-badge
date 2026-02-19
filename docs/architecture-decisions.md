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
