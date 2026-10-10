import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/local_room_repository.dart';
import 'package:gather/domain/models.dart';
import 'package:gather/domain/room_event.dart';
import 'package:gather/domain/room_snapshot.dart';
import 'package:gather/domain/room_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These cover the rules the plan says the server must enforce, so they are
/// written against the repository rather than the UI on purpose: when the
/// backend lands, the same cases have to hold there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalRoomRepository repo;

  setUp(() {
    // The repository persists rooms through SharedPreferences, which has no
    // platform implementation under the test runner. Without this every write
    // is swallowed and "survives a restart" cases would pass vacuously.
    SharedPreferences.setMockInitialValues({});
    repo = LocalRoomRepository(
      random: Random(42),
      minimumVotingDuration: const Duration(milliseconds: 30),
      voteOrderFreeze: const Duration(milliseconds: 150),
    );
  });

  tearDown(() => repo.dispose());

  Future<RoomSnapshot> makeRoom({RoomType type = RoomType.meetup}) {
    return repo.createRoom(
      title: 'Test room',
      type: type,
      ownerName: 'Alex',
      ownerEmoji: '🙌',
      expectedCount: 20,
    );
  }

  Future<RoomSnapshot> makeRoomWithTitle(String title) {
    return repo.createRoom(
      title: title,
      type: RoomType.meetup,
      ownerName: 'Alex',
      ownerEmoji: '🙌',
    );
  }

  group('room creation', () {
    test('allocates a 5 character code with no ambiguous glyphs', () async {
      final snapshot = await makeRoom();
      expect(snapshot.room.code, hasLength(5));
      expect(
        snapshot.room.code,
        matches(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$')),
      );
    });

    test('seeds an agenda and points at the first step', () async {
      final snapshot = await makeRoom();
      final template = templateFor(RoomType.meetup);

      expect(snapshot.steps, hasLength(template.defaultSteps.length));
      expect(snapshot.room.currentStepId, isNotNull);
      expect(snapshot.currentStep?.title, template.defaultSteps.first);
      expect(snapshot.stateFor(snapshot.currentStep!), AgendaStepState.current);
    });

    test('the organizer is a member with the owner role', () async {
      final snapshot = await makeRoom();
      final viewer = snapshot.viewer!;
      expect(viewer.isOwner, isTrue);
      expect(viewer.displayName, 'Alex');
    });

    test('rejects a blank title', () async {
      expect(
        () => makeRoomWithTitle('   '),
        throwsA(isA<GatherRuleException>()),
      );
    });
  });

  group('joining', () {
    test('a meetup QR join counts as arriving', () async {
      final room = await makeRoom();
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
        viaQr: true,
      );

      expect(guest.viewer!.isCheckedIn, isTrue);
      expect(guest.checkedInCount, 1);
    });

    test('a movie room uses the button instead, even from a QR', () async {
      final room = await makeRoom(type: RoomType.movie);
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🍿',
        viaQr: true,
      );

      expect(guest.viewer!.isCheckedIn, isFalse);

      await repo.checkIn(code: room.room.code, memberId: guest.viewerMemberId!);
      final after = await repo.getRoomState(room.room.code);
      expect(after.checkedInCount, 1);
    });

    test('rejects an unknown code with a readable message', () {
      expect(
        () => repo.joinRoom(code: 'ZZZZZ', displayName: 'Sam', emoji: '🔥'),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains("couldn't find a room"),
          ),
        ),
      );
    });

    test('rejects a blank name', () async {
      final room = await makeRoom();
      expect(
        () =>
            repo.joinRoom(code: room.room.code, displayName: '  ', emoji: '🔥'),
        throwsA(isA<GatherRuleException>()),
      );
    });

    test('a rejoining guest gets the same member, check-in intact', () async {
      final room = await makeRoom();
      final code = room.room.code;

      final first = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
        guestId: 'device-abc',
        viaQr: true,
      );
      expect(first.checkedInCount, 1);

      // Same phone, app closed and reopened. It must not become a new person.
      final second = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
        guestId: 'device-abc',
      );

      expect(second.viewerMemberId, first.viewerMemberId);
      expect(second.members, hasLength(first.members.length));
      expect(second.checkedInCount, 1);
      expect(second.viewer!.isCheckedIn, isTrue);
    });

    test('a different device joining is a different member', () async {
      final room = await makeRoom();
      final a = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
        guestId: 'device-a',
      );
      final b = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
        guestId: 'device-b',
      );

      expect(b.viewerMemberId, isNot(a.viewerMemberId));
      expect(b.members, hasLength(3));
    });

    test('checking in twice is refused', () async {
      final room = await makeRoom();
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
        viaQr: true,
      );
      expect(
        () =>
            repo.checkIn(code: room.room.code, memberId: guest.viewerMemberId!),
        throwsA(isA<GatherRuleException>()),
      );
    });
  });

  group('items and votes', () {
    test('rejects a vote before voting opens', () async {
      final room = await makeRoom();
      await repo.addItem(
        code: room.room.code,
        memberId: room.viewerMemberId!,
        text: 'Option A',
      );
      final items = (await repo.getRoomState(room.room.code)).items;

      expect(
        () => repo.toggleVote(
          code: room.room.code,
          memberId: room.viewerMemberId!,
          itemId: items.first.item.id,
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains("hasn't started"),
          ),
        ),
      );
    });

    test('one vote per member per item, and toggling removes it', () async {
      final room = await makeRoom();
      await repo.addItem(
        code: room.room.code,
        memberId: room.viewerMemberId!,
        text: 'Option A',
      );
      final code = room.room.code;
      final itemId = (await repo.getRoomState(code)).items.first.item.id;

      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 5),
      );

      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: itemId,
      );
      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: itemId,
      );
      expect((await repo.getRoomState(code)).items.first.votes, 0);

      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: itemId,
      );
      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: itemId,
      );
      // A second member voting proves the constraint is per member, not global.
      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );
      await repo.toggleVote(
        code: code,
        memberId: guest.viewerMemberId!,
        itemId: itemId,
      );

      expect((await repo.getRoomState(code)).items.first.votes, 1);
    });

    test('rejects a vote from someone who never joined', () async {
      final room = await makeRoom();
      await repo.addItem(
        code: room.room.code,
        memberId: room.viewerMemberId!,
        text: 'Option A',
      );
      final code = room.room.code;
      final itemId = (await repo.getRoomState(code)).items.first.item.id;
      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 5),
      );

      expect(
        () => repo.toggleVote(code: code, memberId: 9999, itemId: itemId),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('not in this room'),
          ),
        ),
      );
    });

    test('rejects an empty item', () async {
      final room = await makeRoom();
      expect(
        () => repo.addItem(
          code: room.room.code,
          memberId: room.viewerMemberId!,
          text: '   ',
        ),
        throwsA(isA<GatherRuleException>()),
      );
    });
  });

  group('voting lifecycle', () {
    Future<({String code, int ownerId, List<int> itemIds})> seededRoom() async {
      final room = await makeRoom();
      for (final text in ['A', 'B', 'C']) {
        await repo.addItem(
          code: room.room.code,
          memberId: room.viewerMemberId!,
          text: text,
        );
      }
      final snapshot = await repo.getRoomState(room.room.code);
      return (
        code: room.room.code,
        ownerId: room.viewerMemberId!,
        itemIds: snapshot.items.map((i) => i.item.id).toList(),
      );
    }

    test('only the organizer can start a vote', () async {
      final room = await makeRoom();
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      expect(
        () => repo.startVoting(
          code: room.room.code,
          memberId: guest.viewerMemberId!,
          duration: const Duration(minutes: 1),
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('Only the organizer'),
          ),
        ),
      );
    });

    test('refuses to start with nothing to vote on', () async {
      final room = await makeRoom();
      expect(
        () => repo.startVoting(
          code: room.room.code,
          memberId: room.viewerMemberId!,
          duration: const Duration(minutes: 1),
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('at least one option'),
          ),
        ),
      );
    });

    test('picks the most voted item as the winner', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(minutes: 5),
      );

      // A member holds one vote per item, so a second vote needs a second
      // person. That is the plan's unique index showing up as a real limit.
      final guest = await repo.joinRoom(
        code: seed.code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      await repo.toggleVote(
        code: seed.code,
        memberId: seed.ownerId,
        itemId: seed.itemIds[0],
      );
      await repo.toggleVote(
        code: seed.code,
        memberId: guest.viewerMemberId!,
        itemId: seed.itemIds[0],
      );

      await repo.closeVoting(code: seed.code, byMemberId: seed.ownerId);
      final final_ = await repo.getRoomState(seed.code);

      expect(final_.room.status, RoomStatus.closed);
      expect(final_.room.winnerItemId, seed.itemIds[0]);
      expect(final_.room.wasTie, isFalse);
      expect(final_.winner?.item.text, 'A');
      expect(final_.winner?.votes, 2);
    });

    test('breaks a tie at random and flags it so clients can spin', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(minutes: 5),
      );

      // One vote each on A and B: an exact tie.
      await repo.toggleVote(
        code: seed.code,
        memberId: seed.ownerId,
        itemId: seed.itemIds[0],
      );
      await repo.toggleVote(
        code: seed.code,
        memberId: seed.ownerId,
        itemId: seed.itemIds[1],
      );

      await repo.closeVoting(code: seed.code, byMemberId: seed.ownerId);
      final final_ = await repo.getRoomState(seed.code);

      expect(final_.room.wasTie, isTrue);
      expect(seed.itemIds.take(2), contains(final_.room.winnerItemId));
    });

    test('closes with no winner when nobody voted', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(minutes: 5),
      );
      await repo.closeVoting(code: seed.code, byMemberId: seed.ownerId);

      final final_ = await repo.getRoomState(seed.code);
      expect(final_.room.status, RoomStatus.closed);
      expect(final_.room.winnerItemId, isNull);
      expect(final_.room.wasTie, isFalse);
    });

    test('closing twice is harmless', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(minutes: 5),
      );
      await repo.closeVoting(code: seed.code, byMemberId: seed.ownerId);
      final first = await repo.getRoomState(seed.code);

      await repo.closeVoting(code: seed.code, byMemberId: seed.ownerId);
      final second = await repo.getRoomState(seed.code);

      expect(second.room.status, RoomStatus.closed);
      expect(second.room.winnerItemId, first.room.winnerItemId);
    });

    test('a vote after the deadline closes the room and is rejected', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(milliseconds: 40),
      );

      // No scheduled close fires here on purpose: this is the lazy path that
      // catches a missed or restarted job.
      await Future<void>.delayed(const Duration(milliseconds: 90));

      await expectLater(
        repo.toggleVote(
          code: seed.code,
          memberId: seed.ownerId,
          itemId: seed.itemIds[0],
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('already closed'),
          ),
        ),
      );

      final final_ = await repo.getRoomState(seed.code);
      expect(final_.room.status, RoomStatus.closed);
    });

    test('the scheduled close fires on its own', () async {
      final seed = await seededRoom();
      await repo.startVoting(
        code: seed.code,
        memberId: seed.ownerId,
        duration: const Duration(milliseconds: 40),
      );
      await repo.toggleVote(
        code: seed.code,
        memberId: seed.ownerId,
        itemId: seed.itemIds[0],
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final final_ = await repo.getRoomState(seed.code);

      expect(final_.room.status, RoomStatus.closed);
      expect(final_.room.winnerItemId, seed.itemIds[0]);
    });

    test('reactions are broadcast but never stored', () async {
      final seed = await seededRoom();
      final seen = <RoomEvent>[];
      final sub = repo.events(seed.code).listen(seen.add);

      await repo.sendReaction(
        code: seed.code,
        memberId: seed.ownerId,
        emoji: '🔥',
      );
      await Future<void>.delayed(Duration.zero);

      final reaction = seen.where((e) => e.type == RoomEventType.reaction);
      expect(reaction, hasLength(1));
      expect(reaction.first.emoji, '🔥');

      // A later reader must not see yesterday's reactions.
      final final_ = await repo.getRoomState(seed.code);
      expect(final_.room.isVoting, isFalse);
      await sub.cancel();
    });
  });

  group('anonymity and ordering', () {
    test(
      'a guest cannot see who wrote an anonymous item, the owner can',
      () async {
        final room = await makeRoom();
        final code = room.room.code;
        await repo.addItem(
          code: code,
          memberId: room.viewerMemberId!,
          text: 'A quiet question',
          isAnonymous: true,
        );
        await repo.addItem(
          code: code,
          memberId: room.viewerMemberId!,
          text: 'An ordinary one',
        );

        final ownerView = await repo.getRoomState(
          code,
          viewerMemberId: room.viewerMemberId,
        );
        expect(
          ownerView.items.firstWhere((i) => i.item.isAnonymous).canSeeAuthor,
          isTrue,
        );

        final guest = await repo.joinRoom(
          code: code,
          displayName: 'Sam',
          emoji: '🔥',
        );
        final guestView = await repo.getRoomState(
          code,
          viewerMemberId: guest.viewerMemberId,
        );
        final anonymous = guestView.items.firstWhere((i) => i.item.isAnonymous);
        expect(anonymous.canSeeAuthor, isFalse);
        expect(anonymous.authorHidden, isTrue);
      },
    );

    test('items stay oldest-first before a vote opens', () async {
      final room = await makeRoom();
      final code = room.room.code;
      for (final text in ['first', 'second', 'third']) {
        await repo.addItem(
          code: code,
          memberId: room.viewerMemberId!,
          text: text,
        );
      }

      final snapshot = await repo.getRoomState(
        code,
        viewerMemberId: room.viewerMemberId,
      );
      expect(snapshot.items.map((i) => i.item.text), [
        'first',
        'second',
        'third',
      ]);
    });

    test('items reorder by votes while a vote is running', () async {
      final room = await makeRoom();
      final code = room.room.code;
      for (final text in ['A', 'B', 'C']) {
        await repo.addItem(
          code: code,
          memberId: room.viewerMemberId!,
          text: text,
        );
      }
      final ids = (await repo.getRoomState(
        code,
      )).items.map((i) => i.item.id).toList();

      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 5),
      );
      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: ids[2],
      );

      final snapshot = await repo.getRoomState(
        code,
        viewerMemberId: room.viewerMemberId,
      );
      expect(snapshot.items.first.item.id, ids[2]);
      expect(snapshot.items.first.votes, 1);
    });

    test('the order freezes before the deadline so rows stop moving', () async {
      final room = await makeRoom();
      final code = room.room.code;
      for (final text in ['A', 'B', 'C']) {
        await repo.addItem(
          code: code,
          memberId: room.viewerMemberId!,
          text: text,
        );
      }
      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );
      final ids = (await repo.getRoomState(
        code,
      )).items.map((i) => i.item.id).toList();

      // Long enough to pass through the freeze window, short enough to test.
      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(milliseconds: 400),
      );

      // Well before the freeze: the list is live and reorders on votes.
      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: ids[2],
      );
      final beforeFreeze = await repo.getRoomState(
        code,
        viewerMemberId: room.viewerMemberId,
      );
      expect(beforeFreeze.items.first.item.id, ids[2]);

      // Now inside the final stretch: a new vote must not reshuffle the list,
      // because somebody is mid-tap.
      await Future<void>.delayed(const Duration(milliseconds: 280));
      final frozenBefore = await repo.getRoomState(
        code,
        viewerMemberId: room.viewerMemberId,
      );
      final order = frozenBefore.items.map((i) => i.item.id).toList();

      // A vote for the item currently at the top of the list would normally
      // be the thing that moves rows around.
      await repo.toggleVote(
        code: code,
        memberId: guest.viewerMemberId!,
        itemId: ids[0],
      );

      final frozenAfter = await repo.getRoomState(
        code,
        viewerMemberId: room.viewerMemberId,
      );
      // The counts still update; only the order is held.
      expect(frozenAfter.items.firstWhere((i) => i.item.id == ids[0]).votes, 1);
      expect(frozenAfter.items.map((i) => i.item.id).toList(), order);
    });

    test('the snapshot carries the server-side remaining time', () async {
      final room = await makeRoom();
      final code = room.room.code;
      await repo.addItem(code: code, memberId: room.viewerMemberId!, text: 'A');

      // No vote running, so there is no time to report.
      expect((await repo.getRoomState(code)).votingRemainingMs, isNull);

      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 2),
      );
      final remaining = (await repo.getRoomState(code)).votingRemainingMs;
      expect(remaining, isNotNull);
      expect(remaining, greaterThan(0));
      // Close to two minutes, not wildly off.
      expect(remaining, lessThanOrEqualTo(120000));
    });

    test('voteChanged carries the denormalised count', () async {
      final room = await makeRoom();
      final code = room.room.code;
      await repo.addItem(code: code, memberId: room.viewerMemberId!, text: 'A');
      final itemId = (await repo.getRoomState(code)).items.first.item.id;

      final seen = <RoomEvent>[];
      final sub = repo.events(code).listen(seen.add);
      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 5),
      );
      await repo.toggleVote(
        code: code,
        memberId: room.viewerMemberId!,
        itemId: itemId,
      );
      await Future<void>.delayed(Duration.zero);

      final changes = seen.where((e) => e.type == RoomEventType.voteChanged);
      expect(changes, hasLength(1));
      expect(changes.first.count, 1);
      expect(changes.first.itemId, itemId);
      await sub.cancel();
    });
  });

  group('agenda', () {
    test(
      'advancing moves the pointer and finishes the step behind it',
      () async {
        final room = await makeRoom();
        final before = await repo.getRoomState(room.room.code);
        final first = before.currentStep!;

        await repo.advanceStep(
          code: room.room.code,
          memberId: room.viewerMemberId!,
        );
        final after = await repo.getRoomState(room.room.code);

        expect(after.currentStep!.id, isNot(first.id));
        expect(after.stateFor(first), AgendaStepState.done);
        expect(after.currentStepIndex, 1);
      },
    );

    test('the plan refuses to rewind', () async {
      final room = await makeRoom();
      final code = room.room.code;
      await repo.advanceStep(code: code, memberId: room.viewerMemberId!);

      final after = await repo.getRoomState(code);
      final firstStep = after.steps.first;

      expect(
        () => repo.setCurrentStep(
          code: code,
          memberId: room.viewerMemberId!,
          stepId: firstStep.id,
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('only moves forward'),
          ),
        ),
      );
    });

    test('setting the same step twice is a no-op', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final current = (await repo.getRoomState(code)).currentStep!;

      await repo.setCurrentStep(
        code: code,
        memberId: room.viewerMemberId!,
        stepId: current.id,
      );
      final after = await repo.getRoomState(code);
      expect(after.currentStep!.id, current.id);
    });

    test('advancing past the end says so', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      // The room starts on the first step, so reaching the last one takes one
      // fewer advance than there are steps.
      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }

      expect(
        () => repo.advanceStep(code: code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('last step'),
          ),
        ),
      );
    });

    test('only the organizer can advance the plan', () async {
      final room = await makeRoom();
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      expect(
        () => repo.advanceStep(
          code: room.room.code,
          memberId: guest.viewerMemberId!,
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('Only the organizer'),
          ),
        ),
      );
    });

    test('done-ness is derived from the pointer, not stored', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final steps = (await repo.getRoomState(code)).steps;

      // Before moving, the first step is current and the rest upcoming.
      var snapshot = await repo.getRoomState(code);
      expect(snapshot.stateFor(steps[0]), AgendaStepState.current);
      expect(snapshot.stateFor(steps[1]), AgendaStepState.upcoming);

      // One advance and the first becomes done purely by being behind the
      // pointer. There is no flag that could disagree.
      await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      snapshot = await repo.getRoomState(code);
      expect(snapshot.stateFor(steps[0]), AgendaStepState.done);
      expect(snapshot.stateFor(steps[1]), AgendaStepState.current);
    });

    test(
      'the pointer stops on the last step rather than running past it',
      () async {
        final room = await makeRoom();
        final code = room.room.code;
        final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

        for (var i = 0; i < stepCount - 1; i++) {
          await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
        }

        final atEnd = await repo.getRoomState(code);
        expect(atEnd.isAtEndOfPlan, isTrue);
        expect(atEnd.nextStep, isNull);
        expect(atEnd.currentStep!.position, stepCount - 1);

        // One more advance refuses rather than producing a past-the-end state.
        expect(
          () => repo.advanceStep(code: code, memberId: room.viewerMemberId!),
          throwsA(
            isA<GatherRuleException>().having(
              (e) => e.message,
              'message',
              contains('last step'),
            ),
          ),
        );

        // And the pointer is still on the final step afterwards.
        final stillThere = await repo.getRoomState(code);
        expect(stillThere.room.currentStepId, atEnd.room.currentStepId);
      },
    );

    test('adding a step to a room with no steps starts the plan', () async {
      final room = await makeRoom();
      final code = room.room.code;

      // Empty the seeded plan the way an organizer would, then rebuild it.
      for (final step in (await repo.getRoomState(code)).steps) {
        await repo.removeStep(
          code: code,
          memberId: room.viewerMemberId!,
          stepId: step.id,
        );
      }
      expect((await repo.getRoomState(code)).steps, isEmpty);

      await repo.addStep(
        code: code,
        memberId: room.viewerMemberId!,
        title: 'Opening act',
      );
      final after = await repo.getRoomState(code);
      expect(after.steps, hasLength(1));
      expect(after.currentStep?.title, 'Opening act');
    });

    test('advancing through multiple valid steps works end to end', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }

      final atEnd = await repo.getRoomState(code);
      expect(atEnd.isAtEndOfPlan, isTrue);
      expect(atEnd.currentStep!.position, stepCount - 1);

      // Every intermediate step should now be done.
      for (var i = 0; i < stepCount - 1; i++) {
        expect(atEnd.stateFor(atEnd.steps[i]), AgendaStepState.done);
      }
    });

    test('completing the plan marks it complete on the final step', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }

      expect((await repo.getRoomState(code)).isPlanCompleted, isFalse);

      await repo.completePlan(code: code, memberId: room.viewerMemberId!);
      final after = await repo.getRoomState(code);

      expect(after.isPlanCompleted, isTrue);
      expect(after.room.agendaCompleted, isTrue);
      expect(after.isAtEndOfPlan, isTrue);
    });

    test('completing an already-completed agenda is idempotent', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }
      await repo.completePlan(code: code, memberId: room.viewerMemberId!);
      final first = await repo.getRoomState(code);
      expect(first.isPlanCompleted, isTrue);

      // A second call must not throw or corrupt state.
      await repo.completePlan(code: code, memberId: room.viewerMemberId!);
      final second = await repo.getRoomState(code);
      expect(second.isPlanCompleted, isTrue);
      expect(second.room.agendaCompleted, isTrue);
    });

    test('rejecting completion when not on the final step', () async {
      final room = await makeRoom();
      final code = room.room.code;

      // Still on step 0 of N — cannot complete yet.
      expect(
        () => repo.completePlan(code: code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('last step'),
          ),
        ),
      );
    });

    test('only the organizer can complete the plan', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }

      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      expect(
        () => repo.completePlan(code: code, memberId: guest.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('Only the organizer'),
          ),
        ),
      );
    });

    test('advance refuses after plan completion', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }
      await repo.completePlan(code: code, memberId: room.viewerMemberId!);

      expect(
        () => repo.advanceStep(code: code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('already complete'),
          ),
        ),
      );
    });

    test('empty agenda cannot be completed', () async {
      final room = await makeRoom();
      final code = room.room.code;

      // Remove all steps so the agenda is empty.
      for (final step in (await repo.getRoomState(code)).steps) {
        await repo.removeStep(
          code: code,
          memberId: room.viewerMemberId!,
          stepId: step.id,
        );
      }

      expect(
        () => repo.completePlan(code: code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('last step'),
          ),
        ),
      );
    });

    test('completed state surfaces to the snapshot correctly', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;

      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: room.viewerMemberId!);
      }
      await repo.completePlan(code: code, memberId: room.viewerMemberId!);

      final snapshot = await repo.getRoomState(code);
      expect(snapshot.isPlanCompleted, isTrue);
      // A completed plan has nothing in progress: every step reads as done,
      // including the last one the pointer is parked on.
      for (final step in snapshot.steps) {
        expect(snapshot.stateFor(step), AgendaStepState.done);
      }
    });
  });

  group('ending the event', () {
    /// Drives a room to a completed plan. Returns the original snapshot, because
    /// `getRoomState` has no viewer attached and the caller needs the owner id.
    Future<RoomSnapshot> roomWithCompletedPlan() async {
      final room = await makeRoom();
      final code = room.room.code;
      final owner = room.viewerMemberId!;
      final stepCount = templateFor(RoomType.meetup).defaultSteps.length;
      for (var i = 0; i < stepCount - 1; i++) {
        await repo.advanceStep(code: code, memberId: owner);
      }
      await repo.completePlan(code: code, memberId: owner);
      return room;
    }

    test('an unfinished plan cannot be ended', () async {
      final room = await makeRoom();

      expect(
        () =>
            repo.endEvent(code: room.room.code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('Finish the plan'),
          ),
        ),
      );
    });

    test('ending a completed plan marks the event ended', () async {
      final room = await roomWithCompletedPlan();
      expect((await repo.getRoomState(room.room.code)).isEventEnded, isFalse);

      await repo.endEvent(code: room.room.code, memberId: room.viewerMemberId!);

      final after = await repo.getRoomState(room.room.code);
      expect(after.isEventEnded, isTrue);
    });

    test('ending is idempotent', () async {
      final room = await roomWithCompletedPlan();
      final code = room.room.code;
      final owner = room.viewerMemberId!;

      await repo.endEvent(code: code, memberId: owner);
      await repo.endEvent(code: code, memberId: owner);

      final after = await repo.getRoomState(code);
      expect(after.isEventEnded, isTrue);
    });

    test('only the organizer can end the event', () async {
      final room = await roomWithCompletedPlan();
      final guest = await repo.joinRoom(
        code: room.room.code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      expect(
        () => repo.endEvent(
          code: room.room.code,
          memberId: guest.viewerMemberId!,
        ),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('organizer'),
          ),
        ),
      );
    });

    test('an open vote blocks ending the event', () async {
      final room = await roomWithCompletedPlan();
      final code = room.room.code;
      await repo.addItem(
        code: code,
        memberId: room.viewerMemberId!,
        text: 'Option A',
      );
      await repo.startVoting(
        code: code,
        memberId: room.viewerMemberId!,
        duration: const Duration(minutes: 1),
      );

      expect(
        () => repo.endEvent(code: code, memberId: room.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('vote is still open'),
          ),
        ),
      );
    });

    test('an ended room takes no new items or votes', () async {
      final room = await roomWithCompletedPlan();
      final code = room.room.code;
      final owner = room.viewerMemberId!;
      await repo.addItem(code: code, memberId: owner, text: 'Option A');
      await repo.endEvent(code: code, memberId: owner);

      expect(
        () => repo.addItem(code: code, memberId: owner, text: 'Too late'),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('event has ended'),
          ),
        ),
      );
      expect(
        () => repo.startVoting(
          code: code,
          memberId: owner,
          duration: const Duration(minutes: 1),
        ),
        throwsA(isA<GatherRuleException>()),
      );
    });
  });

  group('surviving a restart', () {
    /// Drives a room to a completed, ended plan and returns its code.
    Future<String> endedRoom() async {
      final room = await makeRoom();
      final code = room.room.code;
      final owner = room.viewerMemberId!;
      final n = templateFor(RoomType.meetup).defaultSteps.length;
      for (var i = 0; i < n - 1; i++) {
        await repo.advanceStep(code: code, memberId: owner);
      }
      await repo.completePlan(code: code, memberId: owner);
      await repo.endEvent(code: code, memberId: owner);
      return code;
    }

    test('a completed and ended plan is still there after a restart', () async {
      final code = await endedRoom();

      // A second repository over the same storage is what a relaunch looks
      // like: the in-memory rooms are gone and only the file remains.
      final reopened = LocalRoomRepository();
      await _settle();

      final restored = await reopened.getRoomState(code);
      expect(restored.isPlanCompleted, isTrue);
      expect(restored.isEventEnded, isTrue);
      expect(restored.steps, isNotEmpty);
    });

    test(
      'the organizer rejoining from the same phone keeps the role',
      () async {
        final room = await repo.createRoom(
          title: 'Test room',
          type: RoomType.meetup,
          ownerName: 'Alex',
          ownerEmoji: '🙌',
          guestId: 'device-abc',
        );
        final code = room.room.code;

        final reopened = LocalRoomRepository();
        await _settle();

        final back = await reopened.joinRoom(
          code: code,
          displayName: 'Alex',
          emoji: '🙌',
          guestId: 'device-abc',
        );
        // Demoting the organizer to a guest in their own room made the agenda
        // permanently unmanageable, because the panel only opens for owners.
        expect(back.viewer?.isOwner, isTrue);
        expect(back.steps, isNotEmpty);
      },
    );

    test(
      'a different phone joining a restored room is still a guest',
      () async {
        final room = await repo.createRoom(
          title: 'Test room',
          type: RoomType.meetup,
          ownerName: 'Alex',
          ownerEmoji: '🙌',
          guestId: 'device-abc',
        );

        final reopened = LocalRoomRepository();
        await _settle();

        final guest = await reopened.joinRoom(
          code: room.room.code,
          displayName: 'Sam',
          emoji: '🔥',
          guestId: 'device-xyz',
        );
        expect(guest.viewer?.isOwner, isFalse);
      },
    );

    test('check-in is refused once the event has ended', () async {
      final code = await endedRoom();
      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );

      expect(
        () => repo.checkIn(code: code, memberId: guest.viewerMemberId!),
        throwsA(
          isA<GatherRuleException>().having(
            (e) => e.message,
            'message',
            contains('event has ended'),
          ),
        ),
      );
    });

    test('schema mismatch invokes onSchemaMismatch and clears storage', () async {
      // Seed some data under the old schema.
      final room = await makeRoom();
      final code = room.room.code;

      // Simulate a schema bump by setting the stored version ahead.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('gather.schemaVersion', 99);

      // A new repository with a mismatch callback should clear storage.
      bool? mismatchCalled;
      final reopened = LocalRoomRepository(onSchemaMismatch: () {
        mismatchCalled = true;
      });
      await _settle();

      expect(mismatchCalled, isTrue);
      expect(await reopened.getRoomState(code), throwsA(isA<GatherRuleException>()));

      reopened.dispose();
    });
  });
}

/// Persistence is fire-and-forget, so give the writes a turn to land before
/// asserting against what a fresh repository reads back.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));
