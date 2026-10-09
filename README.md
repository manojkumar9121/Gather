# Gather

**WhatsApp is where you talk. Gather is where you decide.**

Gather is a live group room for any get-together. An organizer creates a room and shares a code or QR. Everyone who joins sees the same live state and can post ideas, upvote, check in, and watch a timed vote close with a winner.

## What it does

- **Guest join:** Scan QR or enter a 5-character code. Type a name, pick an emoji — no account needed.
- **Organizer sign-in:** Real auth (email/password via Serverpod auth) to create and control rooms.
- **Live upvotable items:** Questions, suggestions, stops — all covered by one `Item` model.
- **Timed voting:** Organizer sets a deadline; every phone shows a countdown anchored to the server. Voting closes on the server, winner is revealed.
- **Live check-in:** Counter visible to everyone. Joining via QR in meetup rooms auto-checks in.
- **Shared agenda:** Ordered steps with a current pointer. Everyone sees "where are we?" without scrolling.
- **Reveal moment:** Countdown, hidden votes in final 10 seconds, drumroll, confetti for winner. Ties broken by server-side random pick.
- **Live emoji reactions:** Ephemeral bursts that float up; never stored.
- **Recap card:** Winner, attendance, first arrival, most upvoted idea. Shareable image.

## Design

Friendly and a little playful. Deep ultramarine (`#3A2FE0`) with warm gold (`#FFC83D`) as the single accent. Rounded, large tap targets, one memorable moment (the reveal) and everything else quiet.

The logo (`gather-logo-1024.png`) uses dots gathering into a G with a gold center dot — it is the app icon and splash.

## How it works locally

```bash
flutter pub get
flutter run
```

No server required. The app runs entirely in memory (`LocalRoomRepository`). Every domain rule — voting deadlines, duplicate votes, agenda pointer, role checks — is enforced locally, identical to what the server will enforce once deployed.

## Serverpod backend (included, not deployed)

The `server/` folder contains the full Serverpod backend:

- `protocol/*.spy.yaml` — database models: Room, Member, Item, Vote, AgendaStep.
- `endpoint/gather_endpoint.dart` — endpoints implementing the server-side rules (auth, voting close with scheduled future calls, agenda, reactions, snapshot stream).
- `migrations/` — SQL migration setting up PostgreSQL tables.
- `config/production.yaml` — server configuration.

### How to deploy it yourself

1. Install prerequisites: Dart SDK (^3.12.2), Serverpod CLI, PostgreSQL.
2. Configure: `cp server/config/production.yaml server/config/development.yaml`
3. Generate and migrate:
   ```bash
   cd server
   serverpod generate
   serverpod create-migration
   ```
4. Start: `serverpod run`
5. Point the Flutter client at your server by swapping `LocalRoomRepository` for a `ServerpodRoomRepository` (interface defined in `lib/data/room_repository.dart`).

See `docs/deploy/DEPLOYMENT.md` for full instructions.

## Serverpod stack usage

- **Auth:** Email/password for organizers (`auth`). Guests persist via device UUID (`guest_identity.dart`, `shared_preferences`).
- **ORM & Migrations:** `.spy.yaml` models mapped to PostgreSQL. Migration in `migrations/`.
- **Streaming:** `roomEvents()` broadcasts `RoomEvent` (member joined, vote changed, voting started/closed, step changed, reaction). Clients fetch `getRoomState()` first, then subscribe.
- **Scheduled tasks:** Vote close schedules a future call. Lazy close also runs on every read so a missed/restarted job never leaves a room stuck.
- **File uploads:** Endpoint structure supports image uploads; banner upload is the planned use.

## Screens

1. **Landing:** Create room, Join room.
2. **Join:** Code entry or QR scan, name, emoji.
3. **Room:** Now (agenda + check-in), Items (voting), People (attendance).
4. **Organizer panel:** QR display, live check-in counter, vote start/duration picker, agenda control.
5. **Voting & reveal:** Countdown, live counts, reveal animation.
6. **Recap card:** Final summary image.

## Key rules (enforced on server, mirrored locally)

- **Permission matrix:** Only organizer creates/closes rooms, starts/closes votes, advances agenda. Guests can add items, vote, react, check in.
- **Anonymous items:** Guests see "Anonymous"; organizers see the real author for moderation.
- **Voting rules:** Reject past deadline; one vote per item per member; toggle removes vote; denormalized `voteCount`; server picks winner (random on tie); zero votes show designed empty state.
- **Clock skew:** Client never computes deadline from its own clock. Server reports `votingRemainingMs`; client anchors countdown to that.
- **Ordering freeze:** Final 10 seconds freeze item order so no one is mid-tap when rows swap.
- **Foreground resync:** On `AppLifecycleState.resumed`, re-fetch snapshot and re-subscribe to stream.
- **Guest identity:** `guestId` UUID persists across restarts. Same `guestId` → same `Member` with check-in intact.
- **QR is three separate problems:** Generate (`qr_flutter`), scan (`mobile_scanner` with camera permission), receive as deep link (`app_links` with `gather://` scheme registered in `AndroidManifest.xml` and `Info.plist`).

## Room templates (config only)

| Type | Item label | Check-in | Agenda | Extras |
|---|---|---|---|---|
| `meetup` | Questions | QR at door (QR join auto-checks in) | Schedule | — |
| `trip` | Stop ideas | Manual button | Itinerary | Packing list, expenses |
| `movie` | Movie picks | Manual button | Showtime | Snacks, expenses |

Only `meetup` and `movie` are required for the demo. `trip` is a label/config change.

## Known limitations / what's next

- Multi-device sync requires deploying the `server/` backend.
- Checklist and expense modules are planned but not implemented.
- Banner image upload is structured but not required.
- Live location was cut; replaced by manual "running late" button concept.
- Demo video and deployed link will be added once the server is deployed.

## Build order (from the plan)

Phase -1 (client-first prototype): **Done.** 47 tests cover rules, code contract, create flow.
Phase 0 (server skeleton + auth): Server code written; not deployed.
Phase 1 (deploy skeleton): **Future** — deploy `server/` and confirm create/join from real phone.
Phase 2-6 (streaming, organizer, reveal, fun layer, real people test, demo): Ready to implement once server is deployed.

## Tests

```bash
flutter test
```

Tests cover room rules, code contract, and create flow against the local repository so the same assertions will hold against the server implementation.

## Images / screenshots

- `docs/` — Screenshots of landing, create, join (QR), room (Now), items, voting, people, organizer panel, reveal, voted result.
- `gather-logo-1024.png` — Logo for icon and splash.
