# 320x240 Message Window Typesetting Contract (v1)

This document defines deterministic rendering for the message window only.
It is intentionally independent of host UI framing.

## Scope

1. Target surface: `320x240` message window.
2. Output forms:
- web text rendering for copy/paste
- badge/window raster output (`320x240`)
3. Out of scope:
- host UI bars, status, nav, trust badges, and other outer layout concerns

## Fixed window geometry

All coordinates are absolute pixels inside the `320x240` window.

1. Window rect: `x=0, y=0, w=320, h=240`
2. Content rect: `x=8, y=8, w=304, h=224`
3. Content rect is the only drawing region for message text and inline artifacts.

## Text profile

1. Font size: `16px`
2. Line height: `18px`
3. Max lines for `right|left|none`: `12`
4. Max lines for `top|bottom`: `6`
5. Font IDs: `nsm`, `ns`, `ser`, `atk`, `ibm`

## Supported markdown subset

1. Paragraphs and explicit newlines
2. Headings `#` through `######`
3. Block quotes (`>`)
4. Ordered/unordered lists
5. Task items (`- [ ]`, `- [x]`)
6. Inline code and fenced code blocks
7. Links `[label](url)` and bare URLs
8. Horizontal rules (`---`, `***`, `___`)
9. Table-like rows (`| cell | cell |`)
10. Strikethrough (`~~text~~`)

## Typst-style message directives (non-printing)

1. `#font("nsm"|"ns"|"ser"|"atk"|"ibm")`
2. `#place("right"|"left"|"top"|"bottom"|"none")`
3. `#qr("https://example.com")`
4. `#event("YYYY-MM-DD HH:MM", "Title", "Location")`
5. `#contact("Name", "phone", "email", "https://url")`

Directive lines do not render as message text lines.

## Placement profiles

1. `right` (default):
- text rect `x=0, y=0, w=200, h=224`
- artifact rect `x=208, y=0, w=96, h=224`
- max artifacts: `2`

2. `left`:
- text rect `x=104, y=0, w=200, h=224`
- artifact rect `x=0, y=0, w=96, h=224`
- max artifacts: `2`

3. `top`:
- text rect `x=0, y=104, w=304, h=120`
- artifact rect `x=0, y=0, w=304, h=96`
- max artifacts: `3`

4. `bottom`:
- text rect `x=0, y=0, w=304, h=120`
- artifact rect `x=0, y=128, w=304, h=96`
- max artifacts: `3`

5. `none`:
- text rect `x=0, y=0, w=304, h=224`
- no artifact rect
- max artifacts: `0`

## Parsing and shaping phases

1. Normalize:
- convert line endings to `\n`
- trim trailing whitespace per line

2. Parse:
- tokenize supported markdown
- parse non-printing directives
- extract artifact payloads from URLs and directives

3. Shape:
- measure with selected font profile
- wrap deterministically within placement text rect width

4. Fit check:
- enforce line and artifact capacity for selected placement
- overflow is invalid for v1 (no pagination fallback)

5. Paint:
- render text + inline artifacts into `320x240`
- web and badge derive from the same shaped model

## Output contract

For each render:

1. `render_spec_version`
2. `render_profile_id` (`msg_320x240_v1`)
3. `page_index=1`, `page_count=1`
4. `plain_text` (as rendered in the window)
5. `image_320x240`
6. `qr_artifacts`

## Repeatability constraints

1. No dynamic font scaling in v1
2. No variable content padding/margins in v1
3. No adaptive pagination in v1
4. Line/artifact placement depends only on:
- normalized message
- directive values
- fixed geometry
- selected font metrics

## Bit-exact fixture source

Use `typst/social-badge/layout.typ` and `scripts/check_typst_layouts.cr` to
generate and verify deterministic PNG hashes from raw message-content test
cases.
