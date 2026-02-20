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

1. `message` raw authored text (including Typst-style control directives).
2. Optional defaults for `default-font` and `default-placement`.

The package renders only the message window (`320x240`) with a fixed `8px` inset
content box (`304x224`). It does not render device chrome.

Supported non-printing directives inside `message`:

1. `#font("nsm"|"ns"|"ser"|"atk"|"ibm")`
2. `#place("right"|"left"|"top"|"bottom"|"none")`
3. `#qr("https://...")`
4. `#event("YYYY-MM-DD HH:MM", "Title", "Location")`
5. `#contact("Name", "phone", "email", "https://url")`

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
