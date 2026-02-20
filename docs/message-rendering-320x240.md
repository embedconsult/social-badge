# 320x240 Message Typesetting Contract (v1)

This document defines a deterministic message rendering pipeline with two output
targets:

1. Web output for readable text and copy/paste.
2. Badge output as image data for LVGL display.

The key requirement is that both targets are produced from the same layout
engine contract so the `320x240` result is predictable and repeatable.

## Core policy

1. Trust is chrome-only.
- Trust indicators are rendered in top chrome.
- Trust text/icons must never be inserted into message body layout.

2. Message viewport is content-only.
- Message body contains author text and markdown styling.
- Transport metadata (dedupe key, hops, origin) is not body content.

3. Browser layout is canonical.
- The browser implementation is the reference typesetter for `MSG_320x240`.
- Badge rendering uses the same layout rules and consumes produced image data.

## Fixed geometry (400x300 screen)

All coordinates are absolute pixels.

1. Top chrome: `x=0, y=0, w=400, h=24`
- Trust badge, author label, relative timestamp.

2. Message viewport: `x=40, y=24, w=320, h=240`
- Only region where message content is painted.

3. Bottom chrome: `x=0, y=264, w=400, h=36`
- Fixed status band for device/system chrome (no pagination controls in v1).

4. Side gutters:
- Left: `x=0, y=24, w=40, h=240`
- Right: `x=360, y=24, w=40, h=240`

5. Content box within viewport:
- `x=48, y=32, w=304, h=224`
- Fixed `8px` padding inside `MSG_320x240`.

## Text profile for compact rendering

Typography baseline:

1. Font size: `16px`
2. Line height: `18px`
3. Max lines in right/left layout: `12`
4. Max lines in top/bottom layout: `6`
5. Font profile IDs: `noto-sans-mono`, `noto-sans`, `noto-serif`, `atkinson`, `ibm-plex-mono`

Extended markdown set (v1 preview):

1. Paragraphs and explicit newlines
2. Headings `#` through `######`
3. Block quotes with `>`
4. Unordered and ordered lists
5. Task list items `- [ ]` and `- [x]`
6. Inline code and fenced code blocks
7. Links `[label](url)` and bare URLs
8. Horizontal rules (`---`, `***`, `___`)
9. Table-like rows using `| cell | cell |`
10. Strikethrough `~~text~~`

Typst-style extension directives:

1. Font: `#font("nsm"|"ns"|"ser"|"atk"|"ibm")`
2. Placement: `#place("right"|"left"|"top"|"bottom"|"none")`
3. QR payload: `#qr("https://example.com")`
4. Calendar entry: `#event("YYYY-MM-DD HH:MM", "Title", "Location")`
5. Contact card: `#contact("Name", "phone", "email", "https://url")`

Typst directives are non-printing control lines in preview/layout. They produce
QR artifacts and placement behavior but do not render as body text lines.
If no `#place(...)` directive is present, inline artifacts use right-float layout.

UTF-8 behavior:

1. Render glyph when available.
2. Missing glyph fallback is deterministic (`?`).
3. Never silently drop characters.

Compactness rules:

1. Preserve author text; do not rewrite/expand content.
2. Do not expand links/emojis into verbose labels.
3. Keep wrapping deterministic rather than adaptive.

## Rendering phases (strict order)

Each phase has explicit input/output to keep behavior testable.

1. Normalize
- Input: raw post text.
- Output: normalized text with `\n` line endings and trailing whitespace trimmed.

2. Parse
- Input: normalized text.
- Output: token stream for supported markdown subset.
- Unknown markdown syntax is treated as plain text tokens.

3. Shape
- Input: token stream + font metrics + content width (`304px`).
- Output: wrapped line boxes with deterministic breakpoints.
- Word-wrap first, hard-wrap unbreakable tokens second.

4. Paginate
- Input: line boxes + line/artifact capacity for the selected placement profile.
- Output: a single `320x240` page fit result.
- Overflow is validation failure, not pagination.

5. Paint Web
- Input: page model.
- Output: DOM/text rendering preserving selectable text for copy/paste.

6. Paint Badge Artifact
- Input: same page model used by web paint.
- Output: `320x240` raster image payload for LVGL.

7. Build Artifacts
- Input: normalized message content.
- Output: QR payload candidates for URLs, `#qr(...)`, `#event(...)`
  entries (iCalendar), and `#contact(...)` entries (vCard), plus inline
  artifact placement mode from `#place(...)`.

## Output contract

For each rendered page, produce:

1. `render_spec_version` (string)
2. `render_profile_id` (for example: `msg_320x240_v1`)
3. `page_index=1` and `page_count=1` (v1 fixed page)
4. `plain_text` (copy/paste-friendly text as rendered)
5. `image_320x240` (badge display artifact)
6. `qr_artifacts` (list of URL/event/contact payloads for QR generation)

Notes:

1. Web uses `plain_text` and semantic markup for selection/copy.
2. Badge uses `image_320x240` only; text channel is optional there.
3. Browser and badge outputs must be generated from the same phase outputs and geometry constants.
4. Current web preview QR images are generated via an external QR image service;
   production/device paths should use a local encoder.

## Repeatability constraints

1. No per-message dynamic font scaling in v1.
2. No variable padding/margins per message in v1.
3. No trust-aware content styling inside body lines.
4. Line breaking depends only on normalized text, fixed geometry, and font metrics.
5. Overflow does not create additional pages; content must be edited to fit.

## Non-goals for v1

1. Full CommonMark compatibility
2. Rich HTML layout features
3. Large inline media rendering
4. Automatic summarization or rewriting during render

## Bit-exact fixture source

Use the Typst package at `typst/social-badge/layout.typ` plus
`scripts/check_typst_layouts.cr` to produce and verify deterministic PNG
fixtures for regression checks.
