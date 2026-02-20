# Open Font Profiles (Web + Badge)

This repository uses a small set of open-license font profiles to keep web and
badge rendering predictable.

## Profiles

1. `noto-sans-mono`
- Family: Noto Sans Mono
- License: SIL Open Font License
- Use: default preview profile and deterministic wrapping baseline

2. `noto-sans`
- Family: Noto Sans
- License: SIL Open Font License
- Use: general UI readability

3. `noto-serif`
- Family: Noto Serif
- License: SIL Open Font License
- Use: long-form reading style

4. `atkinson`
- Family: Atkinson Hyperlegible
- License: SIL Open Font License
- Use: accessibility-focused profile

5. `ibm-plex-mono`
- Family: IBM Plex Mono
- License: SIL Open Font License
- Use: compact technical content and code-heavy posts

## Device + Browser alignment

1. Web preview and LVGL should use the same profile ID names.
2. If a profile is unavailable on one side, fall back in this order:
- `noto-sans-mono`
- `noto-sans`
- system fallback
3. For strict pagination parity, test with `noto-sans-mono` first.

## Packaging recommendation

Install the exact TTF/OTF files used by browser preview and badge firmware in a
shared asset bundle so font metrics remain stable across targets.
