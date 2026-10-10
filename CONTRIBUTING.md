# Contributing to Gather

Thanks for your interest in Gather! This guide covers how to run the project locally, add tests, and structure PRs.

## Running locally

```bash
flutter pub get
flutter run
```

No server is required — the app runs fully in local mode (`LocalRoomRepository`) on a single device.

## Running tests

```bash
flutter test
```

Tests cover domain rules against the local repository, so they also validate the behaviour the server implementation must match.

## Code style

- Follow existing conventions: immutable models with `copyWith`, exceptions via `GatherRuleException`, and repository abstraction through `RoomRepository`.
- Public APIs are documented; private helpers are not.
- Keep error messages human-readable — they surface directly to users.

## Adding a feature

1. Write the rule in the repository layer first (`LocalRoomRepository`). Tests should pass before touching the UI.
2. Add or update tests under `test/`. Aim for one test per edge case (empty input, past deadline, wrong role, etc.).
3. Update the UI to surface the new behaviour. Keep widgets thin — state lives in the repository / controller.
4. Run `flutter test` and `flutter analyze` before opening a PR.

## Pull requests

- One logical change per PR.
- Include tests for new rules or bug fixes.
- Update README if the change affects public behaviour (e.g., a new screen or command).
- Reference any relevant issue in the PR description.

## Server backend

The `server/` folder is a Serverpod scaffold. It is not deployed by default — deploy it only when you need multi-device sync. See `docs/deploy/DEPLOYMENT.md` for instructions.
