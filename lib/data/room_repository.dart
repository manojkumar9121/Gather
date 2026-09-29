import '../domain/models.dart';
import '../domain/room_event.dart';
import '../domain/room_snapshot.dart';

/// The boundary between the app and whatever holds room state.
///
/// The prototype implements this locally so the whole app can be built and
/// validated with no backend. When Serverpod arrives, the swap happens here and
/// nowhere else: screens and domain rules only ever see this interface.
///
/// Signatures mirror the plan's endpoints, so the remote implementation is a
/// near-mechanical translation: each method becomes a call, and
/// [getRoomState] / [events] become the snapshot fetch and the room stream.
abstract class RoomRepository {
  /// Changes to the room. Reconnecting clients re-fetch [getRoomState] first,
  /// because a stream only carries what happens from now on.
  Stream<RoomEvent> events(String code);

  /// Everything needed to render the room, for [viewerMemberId].
  Future<RoomSnapshot> getRoomState(String code, {int? viewerMemberId});

  Future<RoomSnapshot> createRoom({
    required String title,
    required RoomType type,
    required String ownerName,
    required String ownerEmoji,
    int? expectedCount,
  });

  Future<RoomSnapshot> joinRoom({
    required String code,
    required String displayName,
    required String emoji,
    bool viaQr = false,
  });

  Future<void> addItem({
    required String code,
    required int memberId,
    required String text,
    bool isAnonymous = false,
  });

  /// Adds a vote if absent, removes it if present.
  Future<void> toggleVote({
    required String code,
    required int memberId,
    required int itemId,
  });

  Future<void> checkIn({required String code, required int memberId});

  Future<void> startVoting({
    required String code,
    required int memberId,
    required Duration duration,
  });

  /// Idempotent, and safe to call from a timer or a lazy check.
  Future<void> closeVoting({required String code, int? byMemberId});

  Future<void> addStep({
    required String code,
    required int memberId,
    required String title,
    DateTime? at,
  });

  Future<void> removeStep({
    required String code,
    required int memberId,
    required int stepId,
  });

  /// Moves the room's current pointer. Forward only.
  Future<void> setCurrentStep({
    required String code,
    required int memberId,
    required int stepId,
  });

  /// Moves to the next step and marks the current one done.
  Future<void> advanceStep({required String code, required int memberId});

  /// Any member can tick a step off; the organizer is not the only one who can
  /// say "that bit is finished".
  Future<void> setStepDone({
    required String code,
    required int stepId,
    required bool isDone,
  });

  /// Ephemeral. Never stored, never replayed.
  Future<void> sendReaction({
    required String code,
    required int memberId,
    required String emoji,
  });
}
