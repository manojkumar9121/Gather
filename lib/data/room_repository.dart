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

  /// Everything needed to render the room, for [viewerMemberId]. Carries
  /// [RoomSnapshot.votingRemainingMs] measured on the server so the client's
  /// countdown does not depend on the phone's clock.
  Future<RoomSnapshot> getRoomState(String code, {int? viewerMemberId});

  Future<RoomSnapshot> createRoom({
    required String title,
    required RoomType type,
    required String ownerName,
    required String ownerEmoji,
    int? expectedCount,
  });

  /// Joins a room, or rejoins it.
  ///
  /// [guestId] is the device-generated identity the phone persists across
  /// restarts. When it matches an existing member the same [Member] comes back
  /// with its check-in intact, so a phone that sleeps mid-demo does not inflate
  /// the check-in count. Omit it for a genuinely new guest.
  Future<RoomSnapshot> joinRoom({
    required String code,
    required String displayName,
    required String emoji,
    String? guestId,
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

  /// Moves to the next step. There is no "past the end" state; at the final
  /// step the pointer stays put and this reports that there is nothing left.
  Future<void> advanceStep({required String code, required int memberId});

  /// Ephemeral. Never stored, never replayed.
  Future<void> sendReaction({
    required String code,
    required int memberId,
    required String emoji,
  });
}
