# Typst Layout Plugin + Bit-Exact Tests

This repository includes a Typst layout package and a Crystal harness to produce
bit-exact PNG fixtures for `MSG_320x240` rendering.

## Files

1. Typst package: `typst/social-badge/layout.typ`
2. Case manifest: `testdata/typst/layout_cases.json`
3. Crystal runner: `scripts/check_typst_layouts.cr`
4. Render outputs: `testdata/typst/out/*.typ` and `testdata/typst/out/*.png`

## Typst package API

Use `render-badge(...)` from `typst/social-badge/layout.typ`.

Parameters:

1. `lines` array of body text lines.
2. `artifacts` array of dictionaries: `(kind: "...", label: "...")`.
3. `font-id` short profile ID: `nsm`, `ns`, `ser`, `atk`, `ibm`.
4. `placement`: `right`, `left`, `top`, `bottom`, `none`.
5. Optional chrome labels: `trust`, `author`, `stamp`.

The package applies fixed geometry for 400x300 chrome and the 320x240 viewport,
with a single-page hard limit and no pagination controls.

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
