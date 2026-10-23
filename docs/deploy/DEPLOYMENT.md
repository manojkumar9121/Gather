# Gather: Self-Deployment Guide

This guide explains how to deploy Gather for yourself. The app runs fully locally by default; this is the server backend if you want multi-device sync.

## What's included

- `lib/` — Flutter client. Fully functional in local mode (single device, in-memory rooms).
- `server/` — Serverpod backend code. Not deployed; deploy it yourself using the steps below.
- `protocol/` — `.spy.yaml` models for Room, Member, Item, Vote, AgendaStep.
- `migrations/` — SQL migration for the room database.
- `endpoint/` — **Scaffolding only**: `GatherEndpoint` is a stub with no database wiring. Do not deploy until the implementation is complete (see TODO banner in the file).

## Before you implement the backend

The scaffold is not a working Serverpod project yet. Anyone picking up the
backend should start from these requirements:

**Project layout.** `endpoint/` and `protocol/` must live under the server
package's `lib/` tree (e.g. `lib/src/endpoints/`, `lib/src/protocol/`), with a
`lib/server.dart` entry point called from `bin/main.dart` — the standard
`serverpod create` layout. The current `server/endpoint/` and
`server/protocol/` locations are a starting point, not a layout `serverpod
generate` / `serverpod run` will discover. Restructure first, then run
`serverpod generate` and confirm the models and endpoint appear in the
generated registry. Do not keep hand-written `Room`/`Member`/`Item` classes in
parallel with the generated protocol classes — the copies in
`endpoint/gather_endpoint.dart` exist only because the scaffold has no
generated models yet.

**Authorization.** The endpoint signatures currently accept a client-supplied
`memberId`. That is acceptable only because nothing is deployed. A real
implementation must:

- derive the authenticated member from the server-side session, never from the
  request payload;
- validate the guest `guestId` token server-side and bind it to the membership
  row;
- check room membership and role on every mutation (a guest must not be able
  to pass another member's id to an organizer-only call);
- replace the `'local-owner'` fallback in `createRoom()` with a per-room owner
  identity resolved from the session.

**Configuration.** `config/production.yaml` is a template: set the real
database host, supply credentials via `SERVERPOD_DATABASE_PASSWORD`, keep
`development: false`, and terminate TLS at a reverse proxy in front of the
server.

**Protocol parity.** `protocol/room.spy.yaml` and the initial migration
already include `agendaCompleted` / `eventEnded` so the server schema matches
the client's `Room`. Keep the two in sync when either side changes — a parity
test running the same scenarios against both repositories is the cheapest way
to hold that line.

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
