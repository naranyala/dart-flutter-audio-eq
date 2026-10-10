# Contributing

## Commands

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # must be green (53 tests)
flutter build linux --debug
flutter run -d linux     # or: bash tool/run-linux.sh (handles libmpv)
```

## Working agreement

- One task in flight at a time; mark `[~]` with date + blocker when paused.
- Every change names its `[Epic/Goal]` from `PYRAMID-OF-INTENTS.md`; pyramid
  violations get re-scoped, not merged.
- Review monthly: promote at most 2 backlog items, retire stale ones.

## What each change needs

- **DSP / parser logic** → unit tests (sine-RMS, round-trips, edge cases).
- **UI** → widget test (renders + key interaction). Plugin-dependent code
  must degrade without plugins: override providers with throws in tests.
- **New feature** → update this docs set + check the `TODOS.md` box.
- **New dependency** → justify in `TODOS.md`/PR: license check first
  (app currently has no LICENSE file — GPL-3.0 proposed), Linux build
  impact (dev packages?), size impact.

## Commit style

Short imperative summary, blank line, bullet body explaining *why*.
Example: `Survive missing libmpv, honest disabled player state`.
