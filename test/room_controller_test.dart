import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/room_repository.dart';
import 'package:gather/domain/models.dart';
import 'package:gather/domain/room_event.dart';
import 'package:gather/domain/room_snapshot.dart';
import 'package:gather/state/room_controller.dart';

/// Mock repository that lets tests control the stream and snapshot without
/// touching SharedPreferences or real timers.
class FakeRepository implements RoomRepository {
  final _eventsController = StreamController<RoomEvent>.broadcast();

  RoomSnapshot? snapshot;
  int callCount = 0;
  String? lastError;

  @override
  Stream<RoomEvent> events(String code) => _eventsController.stream;

  @override
  Future<RoomSnapshot> getRoomState(
    String code, {
    int? viewerMemberId,
  }) async {
    callCount++;
    if (lastError != null) throw GatherRuleException(lastError!);
    return snapshot!;
  }

  @override
  Future<RoomSnapshot> createRoom({
    required String title,
    required RoomType type,
    required String ownerName,
    required String ownerEmoji,
    int? expectedCount,
    String? guestId,
  }) async {
    throw UnimplementedError('Not used by controller tests');
  }

  @override
  Future<RoomSnapshot> joinRoom({
    required String code,
    required String displayName,
    required String emoji,
    String? guestId,
    bool viaQr = false,
  }) async {
    throw UnimplementedError('Not used by controller tests');
  }

  @override
  Future<void> addItem({
    required String code,
    required int memberId,
    required String text,
    bool isAnonymous = false,
  }) async {}

  @override
  Future<void> toggleVote({
    required String code,
    required int memberId,
    required int itemId,
  }) async {}

  @override
  Future<void> checkIn({required String code, required int memberId}) async {}

  @override
  Future<void> startVoting({
    required String code,
    required int memberId,
    required Duration duration,
  }) async {}

  @override
  Future<void> closeVoting({
    required String code,
    int? byMemberId,
  }) async {}

  @override
  Future<void> addStep({
    required String code,
    required int memberId,
    required String title,
    DateTime? at,
  }) async {}

  @override
  Future<void> removeStep({
    required String code,
    required int memberId,
    required int stepId,
  }) async {}

  @override
  Future<void> setCurrentStep({
    required String code,
    required int memberId,
    required int stepId,
  }) async {}

  @override
  Future<void> advanceStep({
    required String code,
    required int memberId,
  }) async {}

  @override
  Future<void> completePlan({
    required String code,
    required int memberId,
  }) async {}

  @override
  Future<void> endEvent({
    required String code,
    required int memberId,
  }) async {}

  @override
  Future<void> sendReaction({
    required String code,
    required int memberId,
    required String emoji,
  }) async {}

  void emit(RoomEvent event) => _eventsController.add(event);
}

/// Build a minimal snapshot with voting active and a known remaining time.
RoomSnapshot votingSnapshot(int remainingMs) {
  return RoomSnapshot(
    room: Room(
      code: 'ABCDE',
      title: 'Test',
      type: RoomType.meetup,
      ownerId: 'owner',
      status: RoomStatus.voting,
      createdAt: DateTime.now(),
      expectedCount: 10,
      wasTie: false,
      winnerItemId: null,
      votingEndsAt: null, // not used; controller uses anchor instead
      currentStepId: 1,
    ),
    members: [],
    items: [],
    steps: [],
    viewerMemberId: 1,
    viewerGuestToken: 'viewer-token',
    votingRemainingMs: remainingMs,
  );
}

void main() {
  late FakeRepository repo;
  late RoomController controller;

  setUp(() {
    repo = FakeRepository();
    controller = RoomController(repo);
  });

  tearDown(() => controller.dispose());

  group('open', () {
    test('fetches the snapshot and subscribes to events', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;

      await controller.open('ABCDE', viewerMemberId: 1);

      expect(controller.code, 'ABCDE');
      expect(controller.viewerMemberId, 1);
      expect(controller.error, isNull);
      expect(controller.busy, isFalse);
      expect(controller.snapshot, same(snapshot));
    });

    test('sets error when repository throws', () async {
      repo.lastError = 'Room not found';
      await controller.open('ABCDE');

      expect(controller.error, 'Room not found');
      expect(controller.snapshot, isNull);
    });

    test('clears busy after open completes', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;

      await controller.open('ABCDE');
      expect(controller.busy, isFalse);
    });
  });

  group('resync', () {
    test('re-fetches and re-subscribes when already open', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;

      await controller.open('ABCDE');
      expect(repo.callCount, 1);

      // A second resync should call getRoomState again.
      await controller.resync();
      expect(repo.callCount, 2);
    });

    test('is a no-op when not in a room', () async {
      repo.snapshot = votingSnapshot(60000);
      await controller.resync();
      expect(repo.callCount, 0);
    });
  });

  group('_onEvent', () {
    test('calls refresh on non-reaction events', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      final beforeCount = repo.callCount;
      repo.emit(const RoomEvent(RoomEventType.stepChanged, stepId: 2));
      await Future<void>.delayed(Duration.zero);

      expect(repo.callCount, greaterThan(beforeCount));
    });

    test('reaction events add to reactions list', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      // Give the open stream subscription time to settle.
      await Future<void>.delayed(Duration.zero);

      repo.emit(const RoomEvent(RoomEventType.reaction, emoji: '🔥', memberId: 1));
      await Future<void>.delayed(Duration.zero);

      expect(controller.reactions, hasLength(1));
      expect(controller.reactions.first.emoji, '🔥');
    });

    test('reactions are removed after three seconds', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      // Give the open stream subscription time to settle.
      await Future<void>.delayed(Duration.zero);

      repo.emit(const RoomEvent(RoomEventType.reaction, emoji: '🔥', memberId: 1));
      await Future<void>.delayed(const Duration(seconds: 3));
      await Future<void>.delayed(Duration.zero);

      expect(controller.reactions, isEmpty);
    });

    test('reaction expiry removes only the matching reaction', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE');
      await Future<void>.delayed(Duration.zero);

      repo.emit(const RoomEvent(RoomEventType.reaction, emoji: '🔥', memberId: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      repo.emit(const RoomEvent(RoomEventType.reaction, emoji: '✨', memberId: 1));

      // Past the first reaction's expiry but before the second one expires.
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      await Future<void>.delayed(Duration.zero);

      expect(controller.reactions, hasLength(1));
      expect(controller.reactions.first.emoji, '✨');
    });
  });

  group('secondsLeft', () {
    test('returns null when not voting', () async {
      final snapshot = RoomSnapshot(
        room: Room(
          code: 'ABCDE',
          title: 'Test',
          type: RoomType.meetup,
          ownerId: 'owner',
          status: RoomStatus.open,
          createdAt: DateTime.now(),
          expectedCount: null,
          wasTie: false,
          winnerItemId: null,
          currentStepId: 1,
        ),
        members: [],
        items: [],
        steps: [],
        viewerMemberId: 1,
        viewerGuestToken: 'viewer-token',
        votingRemainingMs: null,
      );
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      expect(controller.secondsLeft, isNull);
    });

    test('decreases over time during voting', () async {
      final snapshot = votingSnapshot(2000); // 2 seconds left
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      // Allow the ticker to fire a couple of times.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final first = controller.secondsLeft;
      expect(first, isNotNull);
      expect(first!, greaterThanOrEqualTo(0));

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final second = controller.secondsLeft;
      // Should have decreased (or hit zero).
      expect(second, lessThanOrEqualTo(first));
    });

    test('returns zero when time expires', () async {
      final snapshot = votingSnapshot(100); // essentially already expired
      repo.snapshot = snapshot;
      await controller.open('ABCDE');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(controller.secondsLeft, 0);
    });
  });

  group('error handling', () {
    test('surface error via the error getter after a failed action', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE', viewerMemberId: 1);

      repo.lastError = 'Not in this room any more';
      await controller.addItem('Too late');

      expect(controller.error, 'Not in this room any more');
    });

    test('clearError clears the error and notifies', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE', viewerMemberId: 1);

      repo.lastError = 'Something went wrong';
      await controller.addItem('X');
      expect(controller.error, isNotNull);

      controller.clearError();
      expect(controller.error, isNull);
    });
  });

  group('_reanchor', () {
    test('resets anchor when voting ends', () async {
      final snapshot = votingSnapshot(60000);
      repo.snapshot = snapshot;
      await controller.open('ABCDE');
      expect(controller.secondsLeft, isNotNull);

      // Simulate voting ending by returning a non-voting snapshot.
      repo.snapshot = RoomSnapshot(
        room: Room(
          code: 'ABCDE',
          title: 'Test',
          type: RoomType.meetup,
          ownerId: 'owner',
          status: RoomStatus.closed,
          createdAt: DateTime.now(),
          expectedCount: null,
          wasTie: false,
          winnerItemId: null,
          currentStepId: 1,
        ),
        members: [],
        items: [],
        steps: [],
        viewerMemberId: 1,
        viewerGuestToken: 'viewer-token',
        votingRemainingMs: null,
      );
      await controller.refresh();

      expect(controller.secondsLeft, isNull);
    });
  });
}
