# Gather: build plan for the BuildBase app hackathon

You are my coding agent. Build the app described below, in the order given. Read the whole document first, then start with Phase 0. Ask me before adding anything not listed here.

## 1. What Gather is

Gather is a live group room for any get-together. An organizer creates a room and shares a code or QR. Everyone who joins sees the same live state and can post ideas, upvote, check in, and watch a timed vote close with a winner.

Gather does two jobs, and both have to work. It is where a group **decides**, and it is where a group can **see where they are**. A poll alone gives you an answer. A room gives you the answer and the current position: what is happening now, what is next, who is here. The second job is what makes it a room people stay in rather than a link they open once and close.

Tagline: **WhatsApp is where you talk. Gather is where you decide.**

Why it beats a group chat: decisions get buried in chat, nothing ever closes, and nobody knows the current state. Gather has one screen, live counts, a deadline, a reveal, and a running position.

Assumptions (tell me if wrong): Flutter client, Serverpod backend, deployed to Serverpod Cloud, built by me alone in about 14 days. Check the current Serverpod docs for exact APIs before using them, since names and versions change.

Audience is deliberately wide: Gen-Z use cases (concerts, parties, movies, protests) through to office use cases (office parties, group vacations). That spans a wide age range, so the attendee flow stays signup-free, emoji and icons lead over text, tap targets are large, and type stays legible for the older end. No dense tables, no tiny targets, no jargon anywhere.

## 2. Judging targets

- 30% does it work: a reliable core flow beats many half-working features.
- 25% use of the Serverpod stack: auth, ORM and migrations, streaming, scheduled tasks (future calls), file uploads.
- The rest: idea, polish, demo. The demo video and README count for more than a fourth feature.

## 3. Scope

**Must have (core)**
1. Guest join: scan QR or enter code, type a name, pick an emoji, you are in. No signup for attendees.
2. Organizer sign-in with real auth (email or the simplest Serverpod auth option) to create and control rooms.
3. Live upvotable items. One `Item` model covers questions, suggestions, and stops.
4. Timed voting: organizer sets a deadline, all phones show a countdown, voting closes on the server, winner is revealed.
5. Live check-in counter ("12 of 20 here") visible to the organizer and attendees.
6. Shared agenda: an ordered set of steps with optional times and exactly one marked current, so everyone sees where the plan is right now. This is a core job of the app, not a nice-to-have. It reuses the room and the room stream, so it is close to free once items exist.

**Fun layer (after the core works, all cheap because of streaming)**
- Reveal moment: countdown, hidden votes in the last 10 seconds, drumroll and confetti for the winner. Ties are broken by a spinner wheel.
- Live emoji reaction bursts that float up on every screen.
- Recap card at the end: winner, attendance, first to arrive, most upvoted idea. Shareable as an image.
- Swipe-to-vote cards for suggestions (only if time remains).
- Anonymous mode for questions (nearly free with guest auth).
- Marking an agenda step done and showing a progress bar across the steps.

**Nice to have (only if ahead of schedule)**
- Checklist (room-scoped, tick items off live).
- Expenses: split equally and show who owes whom. Nothing more.

**Cut**
- Live location. Use a manual "running late" button instead.
- A plugin or module registry. Templates are config, not architecture.

## 4. Room templates (config only)

Do not build a plugin system. Use one Room screen with a `type` enum and a constant map that sets labels and toggles sections.

| type | item label | check-in | agenda | checklist | expenses |
|---|---|---|---|---|---|
| meetup | Questions | QR at door (joining by QR auto checks in) | Schedule | off | off |
| trip | Stop ideas | "I've arrived" button | Itinerary | packing list | on |
| movie | Movie picks | "I'm here" button | Showtime | snacks | on |

Agenda is on for all three types, because all three have a natural sequence: a meetup has a schedule, a trip has an itinerary, a movie night has a showtime.

Only meetup and movie need to work for the demo. Trip is a label change.

## 5. Data model (Serverpod .spy.yaml, adjust to current syntax)

- `Room`: code (unique, 5 chars, no ambiguous letters), title, type, ownerId, status (open, voting, closed), votingEndsAt, winnerItemId, wasTie, createdAt, expectedCount (denominator for "12 of 20"), currentStepId (the one step the room is on right now)
- `Member`: roomId, userId (owner's account id, or the device `guestId` for a guest), displayName, emoji, role (owner, guest), checkedInAt
- `Item`: roomId, authorMemberId, kind, text, isAnonymous, createdAt, voteCount (denormalised, see voting rules)
- `Vote`: itemId, memberId, createdAt, **unique index on (itemId, memberId)**
- `AgendaStep`: roomId, title, at (nullable, for "break at 9:30"), position (ordering). **No `isDone`** — done-ness comes from `currentStepId`.
- Optional later: `ChecklistItem`, `Expense`, `Participant share`
- Reactions are ephemeral stream events. Do not store them.

Index `Room.code`, `Item.roomId`, `AgendaStep.roomId`, and `Vote.itemId`.

`currentStepId` is a pointer into `AgendaStep` rather than a status enum. Steps before it are done, the pointed-at step is current, steps after it are upcoming. This gives "where we are" for free without a second source of truth.

## 6. Backend behavior

**Streaming.** One stream per room. Define a single serializable `RoomEvent` class with a `type` field and payload: `memberJoined`, `itemAdded`, `voteChanged(itemId, count)`, `checkedIn(count, total)`, `reaction(emoji, memberId)`, `votingStarted(endsAt)`, `votingClosed(winnerItemId, wasTie)`, `stepChanged(stepId)`. Clients send actions through normal endpoints; the server validates and broadcasts events to everyone in the room.

**Snapshot.** Streams only carry changes, so a client that joins late or reconnects after a phone sleeps would render an empty room. Every room needs a `getRoomState(code)` call that returns the room, members, items with their current vote counts, agenda steps, and `votingRemainingMs`. Clients fetch this first, then subscribe. Do not skip this; it is the difference between the app working and the app working on a good network.

**Guest identity.** A guest who closes the app and reopens must get their old `Member` back, not a new one, or the check-in counter inflates the moment a phone sleeps. The device generates a `guestId` UUID and keeps it. `joinRoom` takes that `guestId`; when it matches an existing member, the same member returns with `checkedInAt` intact. Persist exactly four things: `guestId`, display name, emoji, last room code.

**Permission matrix.** "Validate roles" is not a rule until it is written down. Enforce every row on the server.

| Action | Owner | Guest |
|---|---|---|
| Create or close a room | yes | no |
| Start a vote, close early | yes | no |
| Set or advance the current step | yes | no |
| Add an item, vote, react, check in | yes | yes |
| See the author of an anonymous item | yes | no |

That last row is the interesting one. Guests see an anonymous item as just "Anonymous"; the organizer keeps visibility for moderation.

**Voting rules (enforce on the server, never trust the client).**
- Reject votes when room status is not `voting` or `now > votingEndsAt`.
- One vote per member per item (unique constraint). Toggling a vote removes it.
- Denormalise `Item.voteCount` and update it in the same transaction as the vote insert or delete. Counting `Vote` rows on every broadcast and every snapshot is wasted work; this makes both O(1).
- Close is idempotent. Schedule a future call for `votingEndsAt`, and also run a lazy close check whenever a vote arrives after the deadline **and** on every read, so a missed or restarted job cannot leave a room stuck.
- Winner is the item with the most votes, resolved on the server and written to `Room.winnerItemId`. Clients never compute a winner. On a tie, pick randomly among tied items and set `wasTie = true`; the spinner animates to the server's pick, it does not decide it. If clients decided, two phones could reveal different winners. Zero votes: close with no winner and show a designed empty state, not a fallback.

**Clock skew.** Never have a client compute `votingEndsAt - DateTime.now()`. A phone whose clock is three minutes fast ends the vote three minutes early, and two phones then disagree about the reveal. The server reports `votingRemainingMs` in both the snapshot and `votingStarted`, and clients anchor their countdown to that value using their own elapsed time.

**Ordering.** The server owns item order and the client must not re-sort, or rows reshuffle under someone's thumb. Oldest first before voting. Most votes first while voting, then **frozen for the final 10 seconds** so nobody is mid-tap when rows move. Most votes first again after the close, for the result.

**Foregrounding.** iOS drops the connection when the app is backgrounded, so a phone that locks mid-vote returns to a dead stream. On `AppLifecycleState.resumed`, re-fetch `getRoomState` and re-subscribe. Same code path as a fresh join; make sure the lifecycle callback actually calls it.

**Agenda rules.**
- Exactly one step is current at a time, tracked by `Room.currentStepId`. Done-ness is **derived** from that pointer: steps before it are done, the pointed-at step is current, steps after it are upcoming. There is no `isDone` flag, because two sources of truth will disagree.
- Advancing moves the pointer and is idempotent. A late-arriving client cannot rewind the room.
- Only the organizer may set or advance the current step.
- There is no "past the end" state. At the final step the pointer stays put and the advance control disables, so "where are we?" always has an answer.

**Check-in.** The join QR encodes `gather://join/<CODE>`. In meetup rooms, joining through the QR sets `checkedInAt`. Other room types use a manual button. Broadcast the new count on every check-in.

**QR is three separate problems.** Do not conflate them, and do not ship only the first two.
1. **Generate** the QR in the organizer panel (`qr_flutter`).
2. **Scan** it inside the app from the join screen (`mobile_scanner`). Needs the camera permission declared on both platforms.
3. **Receive** it as a deep link when someone scans from the stock camera app (`app_links`). This is the one that gets forgotten, and without it the QR does nothing. Register the `gather` scheme in `Info.plist` (`CFBundleURLTypes`) and `AndroidManifest.xml` (an `intent-filter` with `android:scheme="gather"`), and start the listener at app start-up: a link that cold-launches the app is delivered once, and only to a listener that already exists. Route it to the join screen with the code prefilled, and treat it as a QR arrival for check-in purposes.

One parser serves all three. The scanner, the deep-link handler and the generated link must agree on what a code is, so a QR written one way and read another cannot disagree.

**Cleanup.** Optional scheduled task to close rooms older than 24 hours.

**Uploads.** Optional: event banner image on the room, using Serverpod file uploads. Only do this if there is time; it is mainly for stack score.

## 7. Screens

1. Landing: Create room, Join room.
2. Join: code entry or QR scan, name, emoji.
3. Room: tabs or sections driven by the template config (Now, Items, People, extras).
4. Organizer panel: show join QR, live check-in counter, start voting with a duration picker, close early, advance the agenda.
5. Voting and reveal: countdown, vote list with live counts, winner reveal.
6. Recap card.

**Now** is the first tab, not a detail screen. It shows the current agenda step prominently, the next one beneath it, a progress indicator across all steps, and the live check-in count. Someone opening the room should be able to answer "where are we?" without scrolling.

Design direction: friendly and a little playful. Deep ultramarine (#3A2FE0 range) with warm gold (#FFC83D) as the single accent, soft off-white text. Rounded, large tap targets, one memorable moment (the reveal) and everything else quiet. The logo is in `gather-logo-1024.png` (dots gathering into a G with a gold center dot); use it as the app icon and splash.

## 8. Build order (about 14 days)

**Phase -1: Client-first prototype. Done.** The full app is built against a `RoomRepository` interface with a local in-memory implementation, so every domain rule, screen, and state was validated before a backend existed. UI and domain logic never touch storage directly; when Serverpod is added this becomes an implementation swap, not a rewrite.

Already in the prototype: the three room templates, the shared agenda, the check-in counter, items and votes, timed voting with a scheduled close, the server-picked winner with tie handling, the permission matrix, the server-anchored countdown, order freezing, foreground resync, guest rejoin by device id, QR generate plus scan plus deep link, and the designed zero-vote reveal. 47 tests cover the room rules, the code contract and the create-room flow.

Still single-device, so two-phone sync is not yet demonstrable. That needs the backend.

**Phase 0: Days 1-2.** Serverpod project, Flutter app, models and migrations, auth (organizer) plus guest identity, room create and join by code. Commit early.

**Phase 1: Days 3-4.** Deploy a bare skeleton to Serverpod Cloud now. Confirm the deployed app can create and join a room from a real phone. Do not wait until the end for this.

**Phase 2: Days 4-6.** Items and votes over the room stream. Test two physical devices syncing in real time by day 6.

**Phase 3: Days 7-9.** Organizer panel, timed voting with server-side close, winner screen, tie handling. Test the scheduled close early, including a server restart mid-vote.

**Phase 4: Days 9-10.** QR generation and scanning, check-in counter.

**Phase 5: Days 10-12.** Fun layer in this order: reveal animation, reaction bursts, recap card, then anonymous mode. Checklist or expenses only if everything above is solid.

**Phase 6: Days 13-14.** Test with 3+ real people on real phones, fix bugs, record the demo, write the README. Keep the last day as buffer.

## 9. Rules for you (the agent)

- Server is the source of truth. Validate roles, deadlines, and duplicates on the server.
- Keep every phase shippable. At the end of each phase the app should run and the previous phases should still work.
- No new dependencies or features outside this document without asking me.
- Prefer boring and reliable over clever. If something is taking more than half a day, tell me and propose a cut.
- Handle empty, loading, and error states with plain, specific messages (what went wrong and what to do).
- Commit after each working milestone with a clear message.

## 10. Demo script (60-90 seconds)

Two or three phones on screen. Hero scenario: pick one, either a college fest Q&A or a movie night.
1. Organizer creates a room, QR appears.
2. Two phones scan and join in seconds. Check-in counter ticks up live.
3. Guests post questions or picks. Votes and reaction bursts appear instantly on all phones.
4. Organizer advances the agenda so everyone can see where the plan is.
5. Organizer starts a 30-second vote. Countdown runs on every screen.
6. Reveal: drumroll, winner, confetti. Show the recap card.
7. One closing line: "WhatsApp is where you talk. Gather is where you decide."

## 11. README checklist

- One-paragraph pitch and tagline
- Screenshot or GIF of the reveal
- How each Serverpod feature is used (auth, ORM, streaming, future calls, uploads)
- How to run locally and the deployed link
- Demo video link
- Known limitations and what you would build next (live location, expenses)
