# Typst Runtime Notes

The web preview endpoint (`POST /api/preview/render`) requires:

1. `typst` CLI in `PATH`
2. Vendored QR package files in `typst/vendor/tiaoma`

On startup, the server now probes Typst availability and logs either:

1. `Typst preview enabled: ...`
2. `Typst preview disabled: ...`

The same status is exposed by `GET /health`:

1. `typst_preview_available`
2. `typst_preview_detail`

## Debian/Ubuntu installation options

Recommended for production reproducibility:

1. Install from official Typst release binaries and pin a version.
2. Place `typst` in `/usr/local/bin` (or another managed path).

Example (x86_64):

```bash
TYPST_VERSION="0.14.2"
curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" -o /tmp/typst.tar.xz
tar -xJf /tmp/typst.tar.xz -C /tmp
sudo install -m 0755 /tmp/typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst
typst --version
```

Use `typst-aarch64-unknown-linux-musl.tar.xz` for aarch64.

Alternative option:

1. `cargo install --locked typst-cli`

Notes:

1. Package-manager builds may lag behind upstream releases.
2. Snap installs can hit confinement errors (`failed to load file (access denied)`)
   when rendering project-local Typst/plugin files. For this app, prefer official
   binary or cargo installs.

## Quick verification

```bash
typst --version
curl -fsS http://127.0.0.1:30000/health | jq .
```
