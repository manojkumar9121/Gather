import 'dart:async';
import 'dart:math';

import '../domain/models.dart';
import '../domain/room_event.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import 'room_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// In-memory room store. Holds every rule the server will hold, so the domain
/// behaviour is identical once the backend takes over.
///
/// The room is the source of truth here: role, deadline and duplicate checks
/// all live in this file, never in the UI.
class LocalRoomRepository implements RoomRepository {
  LocalRoomRepository({
    Random? random,
    this.minimumVotingDuration = const Duration(seconds: 5),
    this.voteOrderFreeze = const Duration(seconds: 10),
    this.onSchemaMismatch,
  }) : _random = random ?? Random.secure() {
    unawaited(_loadRooms());
  }

  final Random _random;
  final Map<String, _RoomStore> _rooms = {};
  final Map<String, Timer> _closeTimers = {};

  /// Floor on a vote's length. Exposed so tests can exercise the deadline
  /// path without waiting five seconds.
  final Duration minimumVotingDuration;

  /// Votes stop reshuffling the list this long before the deadline, so nobody
  /// is mid-tap when rows swap under them. Exposed for the same reason as
  /// [minimumVotingDuration].
  final Duration voteOrderFreeze;

  /// Room codes are 5 characters with no ambiguous glyphs: no I, O, 0 or 1,
  /// so a code read aloud or typed off a screen does not get mistyped.
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 5;

  void dispose() {
    for (final timer in _closeTimers.values) {
      timer.cancel();
    }
    _closeTimers.clear();
    for (final store in _rooms.values) {
      store.events.close();
    }
    _rooms.clear();
  }

  // --- lookup -------------------------------------------------------------

  static String normaliseCode(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  _RoomStore _store(String code) {
    final store = _rooms[normaliseCode(code)];
    if (store == null) {
      throw const GatherRuleException(
        "We couldn't find a room with that code. Check the last few "
        'characters and try again.',
      );
    }
    return store;
  }

  String _freshCode() {
    for (var attempt = 0; attempt < 50; attempt++) {
      final buffer = StringBuffer();
      for (var i = 0; i < _codeLength; i++) {
        buffer.write(_codeAlphabet[_random.nextInt(_codeAlphabet.length)]);
      }
      final code = buffer.toString();
      if (!_rooms.containsKey(code)) return code;
    }
    throw StateError('Could not allocate a unique room code.');
  }

  // --- reads --------------------------------------------------------------

  @override
  Stream<RoomEvent> events(String code) => _store(code).events.stream;

  @override
  Future<RoomSnapshot> getRoomState(String code, {int? viewerMemberId}) async {
    final store = _store(code);
    // Safety net for a missed scheduled close: a room whose deadline has
    // passed closes on read, so it can never sit stuck.
    _lazyCloseIfPastDeadline(store);
    return store.snapshot(
      viewerMemberId: viewerMemberId,
      freeze: voteOrderFreeze,
    );
  }

  // --- writes -------------------------------------------------------------

  @override
  Future<RoomSnapshot> createRoom({
    required String title,
    required RoomType type,
    required String ownerName,
    required String ownerEmoji,
    int? expectedCount,
    String? guestId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const GatherRuleException('Give the room a name first.');
    }

    final code = _freshCode();
    final template = templateFor(type);

    final store = _RoomStore(
      Room(
        code: code,
        title: cleanTitle,
        type: type,
        ownerId: 'local-owner',
        status: RoomStatus.open,
        createdAt: DateTime.now(),
        expectedCount: expectedCount ?? kDefaultExpected[type] ?? 0,
        winnerItemId: null,
        wasTie: false,
        currentStepId: null,
      ),
    );
    store._onChanged = () => unawaited(_saveRooms());
    _rooms[code] = store;

    // Seed the agenda so "where are we?" has an answer from the first second
    // rather than showing an empty screen.
    for (var i = 0; i < template.defaultSteps.length; i++) {
      final step = store.newStep(title: template.defaultSteps[i], position: i);
      if (i == 0) store.room = store.room.copyWith(currentStepId: step.id);
    }

    final owner = store.newMember(
      userId: guestId ?? 'owner:$code',
      displayName: ownerName.trim().isEmpty ? 'Organizer' : ownerName.trim(),
      emoji: ownerEmoji,
      role: MemberRole.owner,
    );
    store.ownerMemberId = owner.id;
    unawaited(_saveRooms());

    return store.snapshot(viewerMemberId: owner.id, freeze: voteOrderFreeze);
  }

  @override
  Future<RoomSnapshot> joinRoom({
    required String code,
    required String displayName,
    required String emoji,
    String? guestId,
    bool viaQr = false,
  }) async {
    final store = _store(code);
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const GatherRuleException('Add a name so people know who you are.');
    }

    // A phone that closes and reopens comes back with the same identity and
    // gets the same Member, check-in included. Without this, a phone sleeping
    // mid-vote rejoins as a new person and inflates the count.
    final existing = guestId == null ? null : store.memberByUserId(guestId);
    if (existing != null) {
      return store.snapshot(
        viewerMemberId: existing.id,
        freeze: voteOrderFreeze,
      );
    }

    final template = templateFor(store.room.type);

    // In meetup rooms the QR sits at the door, so scanning it is arriving.
    final autoCheckIn = viaQr && template.autoCheckInOnQr;
    final member = store.newMember(
      userId: guestId ?? 'guest-${_random.nextInt(1 << 32).toRadixString(16)}',
      displayName: name,
      emoji: emoji,
      role: MemberRole.guest,
      checkedInAt: autoCheckIn ? DateTime.now() : null,
    );

    if (autoCheckIn) {
      store.emit(
        RoomEvent.checkedIn(store.checkedInCount, store.members.length),
      );
    }
    store.emit(RoomEvent.memberJoined(member.id));
    unawaited(_saveRooms());

    return store.snapshot(viewerMemberId: member.id, freeze: voteOrderFreeze);
  }

  @override
  Future<void> addItem({
    required String code,
    required int memberId,
    required String text,
    bool isAnonymous = false,
  }) async {
    final store = _store(code);
    final member = _requireMember(store, memberId);

    final clean = text.trim();
    if (clean.isEmpty) {
      throw const GatherRuleException('Type something before posting.');
    }
    if (clean.length > 280) {
      throw const GatherRuleException(
        "That's too long to read on a phone. Keep it under 280 characters.",
      );
    }
    if (store.room.isFinished) {
      throw GatherRuleException(
        store.room.eventEnded
            ? 'This event has ended, so nothing new can be added.'
            : 'This room is closed, so nothing new can be added.',
      );
    }
    if (store.items.length >= 100) {
      throw const GatherRuleException(
        'This room has reached 100 items. Start a new room for more.',
      );
    }

    final kind = templateFor(store.room.type).itemKind;
    final item = store.newItem(
      authorMemberId: member.id,
      kind: kind,
      text: clean,
      isAnonymous: isAnonymous,
    );
    store.emit(RoomEvent.itemAdded(item.id));
  }

  @override
  Future<void> toggleVote({
    required String code,
    required int memberId,
    required int itemId,
  }) async {
    final store = _store(code);
    _requireMember(store, memberId);

    // A vote arriving after the deadline closes the room first, then gets
    // rejected. This is what stops a missed or restarted scheduled close from
    // leaving a room open forever.
    _lazyCloseIfPastDeadline(store);

    if (store.room.eventEnded) {
      throw const GatherRuleException(
        'This event has ended, so voting is closed.',
      );
    }

    if (store.room.status != RoomStatus.voting) {
      throw GatherRuleException(
        store.room.isClosed
            ? 'Voting has already closed. Have a look at the result.'
            : "Voting hasn't started yet. The organizer opens it when they're ready.",
      );
    }

    final item = store.items[itemId];
    if (item == null) {
      throw const GatherRuleException("That item is no longer in this room.");
    }

    final key = '$itemId:$memberId';
    int updatedCount;
    if (store.votes.containsKey(key)) {
      store.votes.remove(key);
      updatedCount = item.voteCount - 1;
    } else {
      store.votes[key] = DateTime.now();
      updatedCount = item.voteCount + 1;
    }

    // The counter moves in the same operation as the vote row, so a snapshot
    // or a broadcast never has to count anything.
    store.items[itemId] = item.copyWith(voteCount: updatedCount);
    store.emit(RoomEvent.voteChanged(itemId, updatedCount));
  }

  @override
  Future<void> checkIn({required String code, required int memberId}) async {
    final store = _store(code);
    final member = _requireMember(store, memberId);
    if (store.room.isFinished) {
      throw GatherRuleException(
        store.room.eventEnded
            ? 'This event has ended, so the count is closed.'
            : 'This room is closed, so the count is closed.',
      );
    }
    if (member.isCheckedIn) {
      throw const GatherRuleException("You're already checked in.");
    }
    store.members[member.id] = Member(
      id: member.id,
      userId: member.userId,
      displayName: member.displayName,
      emoji: member.emoji,
      role: member.role,
      joinedAt: member.joinedAt,
      checkedInAt: DateTime.now(),
    );
    store.emit(RoomEvent.checkedIn(store.checkedInCount, store.members.length));
  }

  @override
  Future<void> startVoting({
    required String code,
    required int memberId,
    required Duration duration,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);

    if (store.room.eventEnded) {
      throw const GatherRuleException(
        'This event has ended, so a vote cannot be started.',
      );
    }
    if (store.room.status == RoomStatus.voting) {
      throw const GatherRuleException('Voting is already running.');
    }
    if (store.room.isClosed) {
      throw const GatherRuleException('This room is already closed.');
    }
    if (store.items.isEmpty) {
      throw const GatherRuleException(
        'Add at least one option before starting a vote.',
      );
    }
    if (duration < minimumVotingDuration) {
      throw GatherRuleException(
        'Give the vote at least ${minimumVotingDuration.inSeconds} seconds.',
      );
    }

    final endsAt = DateTime.now().add(duration);
    store.room = store.room.copyWith(
      status: RoomStatus.voting,
      votingEndsAt: endsAt,
    );
    store.frozenOrder = null;

    // Local stand-in for the server's scheduled future call. Same contract:
    // fire at the deadline, and closing twice must be harmless.
    _closeTimers[store.room.code]?.cancel();
    _closeTimers[store.room.code] = Timer(duration, () {
      _closeTimers.remove(store.room.code);
      unawaited(closeVoting(code: store.room.code));
    });

    // Announce the remaining time rather than an absolute deadline, so the
    // client does not have to trust its own clock.
    store.emit(RoomEvent.votingStarted(duration.inMilliseconds));
  }

  @override
  Future<void> closeVoting({required String code, int? byMemberId}) async {
    final store = _store(code);
    if (byMemberId != null) {
      _requireOwner(store, byMemberId);
    }

    // Idempotent: a timer, a manual close and a lazy read can all land here.
    if (store.room.status == RoomStatus.closed) return;

    _closeTimers[store.room.code]?.cancel();
    _closeTimers.remove(store.room.code);

    int? winnerId;
    var wasTie = false;

    if (store.items.isNotEmpty) {
      final counts = {
        for (final item in store.items.values) item.id: item.voteCount,
      };
      final top = counts.values.reduce(max);
      if (top > 0) {
        final tied = [
          for (final entry in counts.entries)
            if (entry.value == top) entry.key,
        ];
        if (tied.length == 1) {
          winnerId = tied.single;
        } else {
          // The server owns the tie-break and tells clients it happened, so a
          // spinner animates to the server's pick. If the client decided, two
          // phones could reveal different winners.
          winnerId = tied[_random.nextInt(tied.length)];
          wasTie = true;
        }
      }
    }

    store.room = store.room.copyWith(
      status: RoomStatus.closed,
      winnerItemId: winnerId,
      wasTie: wasTie,
    );
    store.emit(RoomEvent.votingClosed(winnerId, wasTie));
  }

  // --- agenda -------------------------------------------------------------

  @override
  Future<void> addStep({
    required String code,
    required int memberId,
    required String title,
    DateTime? at,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);
    final clean = title.trim();
    if (clean.isEmpty) {
      throw const GatherRuleException('Give the step a name.');
    }
    store.newStep(title: clean, position: store.steps.length, at: at);

    // A room with no pointer yet starts on its first step.
    if (store.room.currentStepId == null && store.steps.isNotEmpty) {
      store.room = store.room.copyWith(
        currentStepId: store.steps.values.first.id,
      );
      store.emit(RoomEvent.stepChanged(store.room.currentStepId!));
    }
  }

  @override
  Future<void> removeStep({
    required String code,
    required int memberId,
    required int stepId,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);
    final step = store.steps[stepId];
    if (step == null) return;

    final wasCurrent = store.room.currentStepId == stepId;
    store.steps.remove(stepId);
    _reindex(store);

    if (wasCurrent) {
      // Stepping back is only allowed as a consequence of deleting the
      // pointer itself, never as a way to rewind the room.
      final replacement = store.steps.isEmpty
          ? null
          : store.steps.values.first.id;
      store.room = store.room.withCurrentStep(replacement);
      if (replacement != null) {
        store.emit(RoomEvent.stepChanged(replacement));
      }
    }
  }

  @override
  Future<void> setCurrentStep({
    required String code,
    required int memberId,
    required int stepId,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);
    final target = store.steps[stepId];
    if (target == null) {
      throw const GatherRuleException('That step is no longer in the plan.');
    }

    final current = store.room.currentStepId;
    if (current == stepId) return; // idempotent

    if (current != null) {
      final currentStep = store.steps[current];
      if (currentStep == null) return;
      if (target.position <= currentStep.position) {
        throw const GatherRuleException(
          'The plan only moves forward. Delete a step to change what is behind you.',
        );
      }
    }

    store.room = store.room.copyWith(currentStepId: stepId);
    store.emit(RoomEvent.stepChanged(stepId));
  }

  @override
  Future<void> advanceStep({
    required String code,
    required int memberId,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);

    // Already completed — nothing to advance.
    if (store.room.agendaCompleted) {
      throw const GatherRuleException('The plan is already complete.');
    }

    final currentId = store.room.currentStepId;
    final current = currentId == null ? null : store.steps[currentId];
    final currentPosition = current?.position ?? -1;

    AgendaStep? next;
    for (final step in store.steps.values) {
      if (step.position == currentPosition + 1) {
        next = step;
        break;
      }
    }

    if (next == null) {
      // The pointer stays on the final step rather than moving past the end.
      // There is no beyond-the-end state to design around or to render badly.
      throw const GatherRuleException(
        "This is the last step. Use 'Complete plan' to finish.",
      );
    }

    store.room = store.room.copyWith(currentStepId: next.id);
    store.emit(RoomEvent.stepChanged(next.id));
  }

  @override
  Future<void> completePlan({
    required String code,
    required int memberId,
  }) async {
    final store = _store(code);
    _requireOwner(store, memberId);

    // Idempotent.
    if (store.room.agendaCompleted) return;

    // Must be on the final step before completing.
    if (!store.isAtEndOfPlan) {
      throw const GatherRuleException(
        'Finish every step first. You can only complete the plan at the last step.',
      );
    }

    store.room = store.room.copyWith(agendaCompleted: true);
    store.emit(const RoomEvent(RoomEventType.stepChanged, stepId: -1));
  }

  @override
  Future<void> endEvent({required String code, required int memberId}) async {
    final store = _store(code);
    _requireOwner(store, memberId);

    // Idempotent.
    if (store.room.eventEnded) return;

    // The whole point of ending the event is that the agenda ran its course.
    if (!store.room.agendaCompleted) {
      throw const GatherRuleException(
        'Finish the plan first, then you can end the event.',
      );
    }

    // An open vote would otherwise keep running its timer and could resolve a
    // winner into a room nobody is watching any more.
    if (store.room.isVoting) {
      throw const GatherRuleException(
        'A vote is still open. Close it before ending the event.',
      );
    }

    store.room = store.room.copyWith(eventEnded: true);
    store.emit(const RoomEvent(RoomEventType.stepChanged, stepId: -1));
  }

  @override
  Future<void> sendReaction({
    required String code,
    required int memberId,
    required String emoji,
  }) async {
    final store = _store(code);
    _requireMember(store, memberId);
    // Never stored and never replayed: a late joiner should not see yesterday's
    // reactions.
    store.emit(RoomEvent.reaction(emoji, memberId));
  }

  // --- rule helpers -------------------------------------------------------

  void _lazyCloseIfPastDeadline(_RoomStore store) {
    final endsAt = store.room.votingEndsAt;
    if (store.room.status == RoomStatus.voting &&
        endsAt != null &&
        DateTime.now().isAfter(endsAt)) {
      unawaited(closeVoting(code: store.room.code));
    }
  }

  Member _requireMember(_RoomStore store, int memberId) {
    final member = store.members[memberId];
    if (member == null) {
      throw const GatherRuleException(
        "You're not in this room any more. Rejoin with the code.",
      );
    }
    return member;
  }

  void _requireOwner(_RoomStore store, int memberId) {
    final member = _requireMember(store, memberId);
    if (!member.isOwner) {
      throw const GatherRuleException('Only the organizer can do that.');
    }
  }

  static void _reindex(_RoomStore store) {
    final ordered = store.steps.values.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    for (var i = 0; i < ordered.length; i++) {
      store.steps[ordered[i].id] = AgendaStep(
        id: ordered[i].id,
        title: ordered[i].title,
        at: ordered[i].at,
        position: i,
      );
    }
  }

  // --- persistence ---------------------------------------------------------

  /// Schema version for SharedPreferences persistence. Bump this when the stored
  /// shape changes; old data is cleared on mismatch so a stale room never gets
  /// silently deserialized into the wrong model.
  ///
  /// When bumped, [onSchemaMismatch] (if provided) is invoked before clearing
  /// persisted rooms, giving the app a chance to surface a warning to the user.
  static const _schemaVersion = 2;

  final void Function()? onSchemaMismatch;

  Future<void> _loadRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Read schema version separately from the rooms payload.
      final storedVersion = prefs.getInt('gather.schemaVersion');
      if (storedVersion != null && storedVersion != _schemaVersion) {
        // Schema changed since the last write — clear old data rather than risk
        // corrupt rooms slipping through partial deserialization. Notify the
        // caller so a warning can be surfaced to the user.
        onSchemaMismatch?.call();
        prefs.remove('gather.rooms');
        await prefs.setInt('gather.schemaVersion', _schemaVersion);
        return;
      }
      final data = prefs.getString('gather.rooms');
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final code = map['code'] as String;
          if (_rooms.containsKey(code)) continue;
          final typeName = map['type'] as String? ?? 'meetup';
          final type = RoomType.values.firstWhere(
            (t) => t.wireName == typeName,
            orElse: () => RoomType.meetup,
          );
          final store = _RoomStore(
            Room(
              code: code,
              title: map['title'] as String? ?? 'Restored room',
              type: type,
              ownerId: map['ownerId'] as String? ?? 'local-owner',
              status: RoomStatus.values.firstWhere(
                (s) => s.wireName == map['status'],
                orElse: () => RoomStatus.open,
              ),
              createdAt:
                  DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now(),
              expectedCount: map['expectedCount'] as int?,
              winnerItemId: map['winnerItemId'] as int?,
              wasTie: (map['wasTie'] ?? false) as bool,
              // A pointer to a step that was never restored would strand the
              // plan, so only keep it when the step actually came back.
              currentStepId: _restoredStepId(map),
              agendaCompleted: (map['agendaCompleted'] ?? false) as bool,
              eventEnded: (map['eventEnded'] ?? false) as bool,
            ),
          );
          _restoreSteps(store, map['steps']);
          _restoreMembers(store, map['members'], map['ownerMemberId'] as int?);
          store._onChanged = () => unawaited(_saveRooms());
          _rooms[code] = store;
        }
      }
    } catch (_) {
      // Persistence best-effort for local mode.
    }
  }

  static int? _restoredStepId(Map<String, dynamic> map) {
    final steps = map['steps'];
    if (steps is! List || steps.isEmpty) return null;
    final wanted = map['currentStepId'] as int?;
    if (wanted == null) return null;
    for (final raw in steps) {
      final step = raw as Map<String, dynamic>;
      if (step['id'] == wanted) return wanted;
    }
    return null;
  }

  static void _restoreSteps(_RoomStore store, Object? raw) {
    if (raw is! List) return;
    for (final entry in raw) {
      final map = entry as Map<String, dynamic>;
      final step = AgendaStep(
        id: map['id'] as int,
        title: map['title'] as String,
        position: map['position'] as int,
        at: DateTime.tryParse(map['at'] as String? ?? ''),
      );
      store.steps[step.id] = step;
      if (step.id >= store._nextStepId) store._nextStepId = step.id + 1;
    }
  }

  static void _restoreMembers(
    _RoomStore store,
    Object? raw,
    int? ownerMemberId,
  ) {
    if (raw is! List) return;
    for (final entry in raw) {
      final map = entry as Map<String, dynamic>;
      final member = Member(
        id: map['id'] as int,
        userId: map['userId'] as String,
        displayName: map['displayName'] as String,
        emoji: map['emoji'] as String,
        role: map['role'] == 'owner' ? MemberRole.owner : MemberRole.guest,
        joinedAt:
            DateTime.tryParse(map['joinedAt'] as String? ?? '') ??
            DateTime.now(),
        checkedInAt: DateTime.tryParse(map['checkedInAt'] as String? ?? ''),
      );
      store.members[member.id] = member;
      if (member.id >= store._nextMemberId) {
        store._nextMemberId = member.id + 1;
      }
    }
    store.ownerMemberId = ownerMemberId;
  }

  Future<void> _saveRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = <Map<String, dynamic>>[];
      for (final entry in _rooms.entries) {
        final s = entry.value;
        list.add({
          'code': s.room.code,
          'title': s.room.title,
          'type': s.room.type.wireName,
          'createdAt': s.room.createdAt.toIso8601String(),
          'expectedCount': s.room.expectedCount,
          'currentStepId': s.room.currentStepId,
          'status': s.room.status.wireName,
          'ownerId': s.room.ownerId,
          'winnerItemId': s.room.winnerItemId,
          'wasTie': s.room.wasTie,
          'agendaCompleted': s.room.agendaCompleted,
          'eventEnded': s.room.eventEnded,
          'ownerMemberId': s.ownerMemberId,
          'steps': [
            for (final step in s.steps.values)
              {
                'id': step.id,
                'title': step.title,
                'position': step.position,
                'at': step.at?.toIso8601String(),
              },
          ],
          'members': [
            for (final m in s.members.values)
              {
                'id': m.id,
                'userId': m.userId,
                'displayName': m.displayName,
                'emoji': m.emoji,
                'role': m.role.wireName,
                'joinedAt': m.joinedAt.toIso8601String(),
                'checkedInAt': m.checkedInAt?.toIso8601String(),
              },
          ],
        });
      }
      await prefs.setString('gather.rooms', jsonEncode(list));
      // Persist the schema version alongside the data so a future read can
      // detect structural changes before deserializing stale rooms.
      await prefs.setInt('gather.schemaVersion', _schemaVersion);
    } catch (_) {
      // Persistence best-effort for local mode.
    }
  }
}

class _RoomStore {
  _RoomStore(this.room);

  Room room;
  final Map<int, Member> members = {};
  final Map<int, Item> items = {};
  final Map<int, AgendaStep> steps = {};

  /// Keyed "itemId:memberId", which is exactly the unique index the plan puts
  /// on `Vote`, so one member can hold at most one vote per item. The row set
  /// is kept for the constraint only; counts live on [Item.voteCount].
  final Map<String, DateTime> votes = {};

  final StreamController<RoomEvent> events =
      StreamController<RoomEvent>.broadcast();

  int? ownerMemberId;
  int _nextMemberId = 1;
  int _nextItemId = 1;
  int _nextStepId = 1;

  /// Item ids in the order they were showing when the freeze began. Null until
  /// the vote enters its final seconds.
  List<int>? frozenOrder;

  int get checkedInCount => members.values.where((m) => m.isCheckedIn).length;

  bool get isAtEndOfPlan =>
      room.currentStepId != null && _nextStepAfter(room.currentStepId!) == null;

  AgendaStep? _nextStepAfter(int currentId) {
    final current = steps[currentId];
    if (current == null) return null;
    for (final step in steps.values) {
      if (step.position == current.position + 1) return step;
    }
    return null;
  }

  Member? memberByUserId(String userId) {
    for (final member in members.values) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  void emit(RoomEvent event) {
    if (events.isClosed) return;
    events.add(event);
    // Every mutation broadcasts, so this is the one place that has to remember
    // to persist. Doing it per-caller meant edits made after the room was
    // created were silently dropped on restart.
    _onChanged?.call();
  }

  /// Set by the repository so [emit] can persist. Null in tests that build a
  /// store directly.
  void Function()? _onChanged;

  Member newMember({
    required String userId,
    required String displayName,
    required String emoji,
    required MemberRole role,
    DateTime? checkedInAt,
  }) {
    final member = Member(
      id: _nextMemberId++,
      userId: userId,
      displayName: displayName,
      emoji: emoji,
      role: role,
      joinedAt: DateTime.now(),
      checkedInAt: checkedInAt,
    );
    members[member.id] = member;
    return member;
  }

  Item newItem({
    required int authorMemberId,
    required ItemKind kind,
    required String text,
    required bool isAnonymous,
  }) {
    final item = Item(
      id: _nextItemId++,
      authorMemberId: authorMemberId,
      kind: kind,
      text: text,
      isAnonymous: isAnonymous,
      createdAt: DateTime.now(),
      voteCount: 0,
    );
    items[item.id] = item;
    return item;
  }

  AgendaStep newStep({
    required String title,
    required int position,
    DateTime? at,
  }) {
    final step = AgendaStep(
      id: _nextStepId++,
      title: title,
      position: position,
      at: at,
    );
    steps[step.id] = step;
    return step;
  }

  /// Milliseconds left, measured here so every client agrees. Null unless a
  /// vote is actually running.
  int? get votingRemainingMs {
    if (room.status != RoomStatus.voting) return null;
    final endsAt = room.votingEndsAt;
    if (endsAt == null) return null;
    final remaining = endsAt.difference(DateTime.now()).inMilliseconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// The order items are rendered in. The server owns this: re-sorting on the
  /// client is how a list ends up reshuffling under someone's thumb.
  ///
  /// Before a vote, oldest first. While voting, most votes first until the
  /// freeze. During the final seconds, frozen. After the close, most votes
  /// first again for the result.
  List<Item> orderedItems(Duration freeze) {
    final byCreated = items.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    if (room.status == RoomStatus.open) return byCreated;

    final remaining = votingRemainingMs;
    final inFreeze =
        room.isVoting &&
        remaining != null &&
        remaining <= freeze.inMilliseconds;

    if (inFreeze) {
      frozenOrder ??= byCreated.map((i) => i.id).toList();
      final byId = {for (final item in items.values) item.id: item};
      return [
        for (final id in frozenOrder!)
          if (byId[id] != null) byId[id]!,
      ];
    }

    frozenOrder = null;
    final byVotes = [...byCreated]
      ..sort((a, b) {
        final byCount = b.voteCount.compareTo(a.voteCount);
        return byCount != 0 ? byCount : a.id.compareTo(b.id);
      });
    return byVotes;
  }

  RoomSnapshot snapshot({int? viewerMemberId, required Duration freeze}) {
    final membersSorted = members.values.toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final stepsSorted = steps.values.toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final viewer = viewerMemberId == null ? null : members[viewerMemberId];
    final canSeeAuthors = viewer?.isOwner ?? false;

    return RoomSnapshot(
      room: room,
      members: membersSorted,
      items: [
        for (final item in orderedItems(freeze))
          ItemView(
            item: item,
            votes: item.voteCount,
            votedByMe:
                viewerMemberId != null &&
                votes.containsKey('${item.id}:$viewerMemberId'),
            canSeeAuthor: canSeeAuthors,
          ),
      ],
      steps: stepsSorted,
      viewerMemberId: viewerMemberId,
      viewerGuestToken: viewer?.userId,
      votingRemainingMs: votingRemainingMs,
    );
  }
}
