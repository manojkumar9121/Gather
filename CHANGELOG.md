# Changelog

All notable changes to this project will be documented in this file.

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
