# Gather Architecture

## Overview

Gather is a Flutter app with a clean separation between UI, state, and data. The core idea is that all business rules live in the repository layer, so the same logic works whether the app runs locally or connected to a Serverpod backend.

```
┌─────────────────────────────────────────────────────────────┐
│  UI (screens / widgets)                                     │
│  - RoomScreen, ItemsTab, PeopleTab, OrganizerPanel, etc.   │
│  - Observes RoomController via Provider                    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  State (RoomController)                                     │
│  - Subscribes to one room's event stream                   │
│  - Calls repository methods (createRoom, joinRoom, etc.)   │
│  - Exposes snapshot + reactions via ChangeNotifier         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Repository interface (RoomRepository)                      │
│  - Abstract contract: createRoom, joinRoom, events(), etc. │
│  - Swappable implementations below                         │
└─────────────────────────────────────────────────────────────┘
                   ┌──────────────────┬──────────────────┐
                   ▼                                  ▼
    ┌─────────────────────────┐  ┌─────────────────────────┐
    │ LocalRoomRepository     │  │ ServerpodRoomRepository │
    │ - In-memory store       │  │ (not yet implemented)   │
    │ - SharedPreferences     │  │ - Talks to server/      │
    │   persistence           │  │   endpoint              │
    │ - All rules enforced    │  │                         │
    └─────────────────────────┘  └─────────────────────────┘
```

## Layer responsibilities

### Domain models (`lib/domain/`)

Immutable value objects: `Room`, `Member`, `Item`, `AgendaStep`, `RoomSnapshot`, `RoomEvent`. Every model has `copyWith` for state transitions. Exceptions are thrown through `GatherRuleException` with human-readable messages.

### Repository (`lib/data/room_repository.dart`)

The `RoomRepository` interface defines the contract. Both `LocalRoomRepository` and a future `ServerpodRoomRepository` implement it. This lets you swap backends without touching UI code.

### Local implementation (`lib/data/local_room_repository.dart`)

In-memory store backed by SharedPreferences for persistence across restarts. Enforces every rule the server will enforce: role checks, voting deadlines, one-vote-per-item, agenda forward-only movement, item ordering freeze before deadline.

### State (`lib/state/room_controller.dart`)

Extends `ChangeNotifier`. Subscribes to a single room's event stream and surfaces `snapshot` + floating reactions to the UI. The controller owns no business logic — it delegates everything to the repository.

### Server scaffold (`server/`)

Serverpod backend with protocol models, endpoint stubs, and a PostgreSQL migration. Not deployed by default; deploy only when multi-device sync is needed. See `docs/deploy/DEPLOYMENT.md`.

## Key design decisions

- **Rules live in the repository, not the UI.** Tests exercise rules directly against `LocalRoomRepository`; the server implementation must match the same assertions.
- **Clock-skew-safe countdowns.** The server (or local store) reports `votingRemainingMs`; the client never computes deadlines from its own clock.
- **Ordering freeze.** Final 10 seconds of voting lock item order so users aren't mid-tap when rows reshuffle.
- **Guest identity persistence.** A device UUID stored in SharedPreferences lets returning users keep their `Member` record and check-in status without server auth.
