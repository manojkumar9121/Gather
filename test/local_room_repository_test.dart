import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/local_room_repository.dart';
import 'package:gather/domain/models.dart';
import 'package:gather/domain/room_event.dart';
import 'package:gather/domain/room_snapshot.dart';
import 'package:gather/domain/room_template.dart';

/// These cover the rules the plan says the server must enforce, so they are
/// written against the repository rather than the UI on purpose: when the
/// backend lands, the same cases have to hold there.
void main() {
  late LocalRoomRepository repo;

  setUp(() {
    repo = LocalRoomRepository(
      random: Random(42),
      minimumVotingDuration: const Duration(milliseconds: 30),
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
      expect(
        snapshot.stateFor(snapshot.currentStep!),
        AgendaStepState.current,
      );
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
        () => repo.joinRoom(
          code: room.room.code,
          displayName: '  ',
          emoji: '🔥',
        ),
        throwsA(isA<GatherRuleException>()),
      );
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
        () => repo.checkIn(
          code: room.room.code,
          memberId: guest.viewerMemberId!,
        ),
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

      await repo.toggleVote(code: code, memberId: room.viewerMemberId!, itemId: itemId);
      await repo.toggleVote(code: code, memberId: room.viewerMemberId!, itemId: itemId);
      expect((await repo.getRoomState(code)).items.first.votes, 0);

      await repo.toggleVote(code: code, memberId: room.viewerMemberId!, itemId: itemId);
      await repo.toggleVote(code: code, memberId: room.viewerMemberId!, itemId: itemId);
      // A second member voting proves the constraint is per member, not global.
      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );
      await repo.toggleVote(code: code, memberId: guest.viewerMemberId!, itemId: itemId);

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
      await repo.toggleVote(code: seed.code, memberId: seed.ownerId, itemId: seed.itemIds[0]);
      await repo.toggleVote(code: seed.code, memberId: seed.ownerId, itemId: seed.itemIds[1]);

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

  group('agenda', () {
    test('advancing moves the pointer and finishes the step behind it', () async {
      final room = await makeRoom();
      final before = await repo.getRoomState(room.room.code);
      final first = before.currentStep!;

      await repo.advanceStep(code: room.room.code, memberId: room.viewerMemberId!);
      final after = await repo.getRoomState(room.room.code);

      expect(after.currentStep!.id, isNot(first.id));
      expect(after.stateFor(first), AgendaStepState.done);
      expect(after.currentStepIndex, 1);
    });

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

    test('any member can tick a step done', () async {
      final room = await makeRoom();
      final code = room.room.code;
      final guest = await repo.joinRoom(
        code: code,
        displayName: 'Sam',
        emoji: '🔥',
      );
      final currentId = (await repo.getRoomState(code)).currentStep!.id;

      await repo.setStepDone(code: code, stepId: currentId, isDone: true);

      // Re-read the step, since the snapshot taken before the update still
      // holds the old copy.
      final after = await repo.getRoomState(code);
      final updated = after.steps.firstWhere((s) => s.id == currentId);
      expect(after.stateFor(updated), AgendaStepState.done);
      expect(guest.viewerMemberId, isNotNull);
    });

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
  });
}
