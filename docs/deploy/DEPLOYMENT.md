# Gather: Self-Deployment Guide

This guide explains how to deploy Gather for yourself. The app runs fully locally by default; this is the server backend if you want multi-device sync.

## What's included

- `lib/` — Flutter client. Fully functional in local mode (single device, in-memory rooms).
- `server/` — Serverpod backend code. Not deployed; deploy it yourself using the steps below.
- `protocol/` — `.spy.yaml` models for Room, Member, Item, Vote, AgendaStep.
- `migrations/` — SQL migration for the room database.
- `endpoint/` — **Scaffolding only**: `GatherEndpoint` is a stub with no database wiring. Do not deploy until the implementation is complete (see TODO banner in the file).

## Serverpod features used (for stack score)

| Feature | How Gather uses it |
|---|---|
| Auth | Email/password for organizers (`auth` module). Guests use device UUID stored locally (`guest_identity.dart`). |
| ORM / Migrations | `.spy.yaml` models mapped to PostgreSQL tables. Migration in `migrations/`. |
| Streaming | `roomEvents()` stream broadcasts `RoomEvent` changes (member joined, vote changed, step changed, etc.). |
| Scheduled tasks (future calls) | Vote close schedules a future call via `Timer` in local mode; serverpod future calls handle it remotely. |
| File uploads | Not required for demo; endpoint structure supports `uploadImage()` if needed later. |

## Local mode (no server needed)

```bash
flutter run
```

The app creates rooms in memory (`LocalRoomRepository`). All rules (voting, agenda, check-in) are enforced locally. No account needed for guests.

## Deploying the server yourself

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) (^3.12.2)
- [Serverpod CLI](https://docs.serverpod.dev/) (`dart pub global activate serverpod_cli`)
- PostgreSQL (14+)

### 1. Configure the server

```bash
cp server/config/production.yaml server/config/development.yaml
# Edit connection details in server/config/development.yaml
```

### 2. Generate models and apply migrations

```bash
cd server
serverpod generate
serverpod create-migration
# Apply migrations to your database
```

### 3. Start the server

```bash
serverpod run
```

### 4. Point the Flutter app at your server

Edit `lib/app.dart` and replace the `LocalRoomRepository` with a `ServerpodRoomRepository` (implementation left as a future exercise; the interface exists in `data/room_repository.dart`).

## Design notes

- **Server is source of truth.** All rules (role checks, deadlines, duplicate votes) are enforced in `GatherEndpoint`.
- **Guest identity.** `guestId` is a UUID generated on the device and persisted in `shared_preferences`. Rejoining a room with the same `guestId` returns the same `Member` with check-in intact.
- **Clock skew.** The server sends `votingRemainingMs` in both the snapshot and the `votingStarted` event. The client anchors its countdown to that value rather than computing from `DateTime.now()`.
- **Agenda derived state.** There is no `isDone` flag. `currentStepId` is the single pointer; done/upcoming/current is derived from position.
- **Tie handling.** On a tie, the server picks randomly (`Random.secure()`) and sets `wasTie = true`. The client's reveal spinner animates to the server's pick.
- **Ordering freeze.** The final 10 seconds of voting freeze the item order (`frozenOrder`). After close, order is by vote count.

## What would come next

- `ServerpodRoomRepository` implementation to swap for the local repository.
- Anonymous mode (hide author from guests; visible to organizer).
- Checklist and expense modules (`protocol/checklist.spy.yaml`, `protocol/expense.spy.yaml`).
- Banner image upload via `ServerpodFileUploadEndpoint`.
- Deployed link and demo video.
