# Typst Layout Plugin + Bit-Exact Tests

This repository includes a Typst layout package and a Crystal harness to produce
bit-exact PNG fixtures for `MSG_320x240` message-window rendering.

## Files

1. Typst package: `typst/social-badge/layout.typ`
2. Case manifest: `testdata/typst/layout_cases.json`
3. Crystal runner: `scripts/check_typst_layouts.cr`
4. Render outputs: `testdata/typst/out/*.typ` and `testdata/typst/out/*.png`

## Typst package API

Use `render-message-window(...)` from `typst/social-badge/layout.typ`.

Parameters:

1. `body` content block containing Typst-authored message layout.
2. Optional `font_id` (`nsm`, `ns`, `ser`, `atk`, `ibm`).

The package renders only the message window (`320x240`) with a fixed `8px` inset
content box (`304x224`).

Built-in helpers exported by the package:

1. `#place(loc)[content]` for alignment within the message window content box.
2. `#qr("https://...")` for compact QR glyph rendering (glyph only, no caption text).

Example:

```typst
#import "../../../typst/social-badge/layout.typ": render-message-window, place, qr
#render-message-window(font_id: "nsm")[
  #place(bottom + right)[#qr("https://bbb.io/badge")]
]
```

## Running checks

Run comparison against expected hashes:

```bash
crystal run scripts/check_typst_layouts.cr
```

Update expected hashes after intentional layout changes:

```bash
crystal run scripts/check_typst_layouts.cr -- --update
```

Run one case only:

```bash
crystal run scripts/check_typst_layouts.cr -- --case qr_only_right
```

## Bit-exact behavior

1. The runner compiles each case with `typst compile --format png --ppi 96`.
2. It computes SHA-256 for each PNG.
3. It compares each hash to `expected_sha256` in the case manifest.
4. In `--update` mode, it rewrites `expected_sha256` values.

If hashes mismatch, the process exits non-zero for CI or local gate checks.
