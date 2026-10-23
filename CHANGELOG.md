# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- Agenda mutations are no longer silent: adding a step to a plan that already has a pointer, removing a non-current step, and removing the last remaining step all broadcast an event (which also persists the room), so these changes are visible to listeners and survive a restart.
- Items, votes, and an active vote's deadline now persist and are restored on restart (including the scheduled close), so a restart no longer wipes the ballot in progress.
- A repository used while storage is still loading no longer reports rooms as missing: reads and event streams wait for restoration to finish.
- Joining only counts as "arriving" (auto check-in) when the code actually came from a scanned QR or deep link, not from any prefilled code field.
- Deleting the current agenda step hands the pointer to the step that took its slot instead of rewinding to the first step.
- Reaction expiry removes only the matching reaction, not every reaction from the same member.
- Countdown is anchored to a monotonic `Stopwatch` instead of the wall clock, so a system-clock change mid-vote cannot jump the displayed time.
- Opening a room subscribes to events before fetching the snapshot, closing the race where a mutation landing between the two was never seen.
- A slow, stale snapshot response can no longer overwrite a newer one (fetch sequence guard).
- Reaction events no longer trigger a full-room refresh, and fired reaction timers drop themselves instead of accumulating for the controller's lifetime.
- Unexpected repository failures (timeouts, transport errors) surface as a retryable error while keeping the last good snapshot, instead of escaping as unhandled async errors; rule errors behave as before.
- Persistence: one malformed room record no longer aborts restoring the rooms stored after it, and save/restore failures are logged in debug builds instead of being silently swallowed.

### Changed
- `server/config/production.yaml` boots with `development: false` and documents that the database host must be set for real deployments.
- Server scaffold aligned with the client model: `agendaCompleted` / `eventEnded` added to `room.spy.yaml`, the initial migration, and the scaffold `Room` class; missing `dart:math` import fixed in the endpoint.
- Added a "Before you implement the backend" section to `docs/deploy/DEPLOYMENT.md` (Serverpod project layout, authorization requirements, configuration, protocol parity).
- The separate `server/` package is excluded from the app's analyzer context; analyze it inside `server/`.
- Added GitHub Actions CI: format check, `flutter analyze`, `flutter test`.

## [1.0.0] — 2026-10-10

### Added
- Local-mode app: room lifecycle, voting with server-anchored countdown, agenda steps, check-in counter, live emoji reactions.
- `LocalRoomRepository` enforcing all business rules (role checks, duplicate-vote rejection, forward-only agenda, ordering freeze).
- Guest identity persistence via device UUID across restarts.
- QR-based join flow with deep-link round-trip test.

### Changed
- Moved planning docs (`gather-build-plan.md`) into `docs/`.
- Added MIT license for open-source publishing.
- Sanitized `server/config/production.yaml` to use `${DB_PASSWORD}` placeholder instead of hardcoded credentials.
- Added schema versioning to SharedPreferences persistence in `LocalRoomRepository`.
- Fixed reaction cleanup to use exact member ID match instead of prefix search.

### Documentation
- Added `CONTRIBUTING.md` with local run instructions and PR guidelines.
- Added `docs/ARCHITECTURE.md` describing the repository-layer abstraction and layer responsibilities.
- Updated `pubspec.yaml` description to reflect the app's purpose.
- Added `client/README.md` explaining the empty client directory.

### Fixed
- `.gitignore`: excluded Flutter build artifacts, Serverpod generated output, and design/planning HTML files.
