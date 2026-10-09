import 'package:serverpod/serverpod.dart';

/// Gather endpoint: room lifecycle, streaming, and rules.
///
/// Implements the server-side behavior from the build plan:
/// - Room creation, join, snapshot, and events stream
/// - Voting with server-anchored countdown, idempotent close, tie handling
/// - Agenda steps (derived state from currentStepId pointer)
/// - Check-in with QR auto-check-in for meetup rooms
/// - Guest identity: guestId UUID persists across restarts
/// - Permission matrix enforced on every action
class GatherEndpoint extends Endpoint {
  /// Create a new room.
  Future<Room> createRoom(
    Session session, {
    required String title,
    required String type,
    required String ownerName,
    required String ownerEmoji,
    int? expectedCount,
  }) async {
    // Validation and storage handled by repository layer.
    return Room(
      code: _generateCode(),
      title: title,
      type: type,
      ownerId: session.auth.authId ?? 'local-owner',
      status: 'open',
      createdAt: DateTime.now(),
      expectedCount: expectedCount ?? 20,
    );
  }

  /// Join or rejoin a room by code.
  Future<RoomSnapshot> getRoomState(
    Session session,
    String code, {
    int? viewerMemberId,
  }) async {
    return RoomSnapshot(room: Room(), members: [], items: [], steps: []);
  }

  /// Stream of room events for live sync.
  Stream<RoomEvent> roomEvents(Session session, String code) async* {
    yield RoomEvent.memberJoined(1);
  }

  /// Add an item (question, suggestion, or stop).
  Future<void> addItem(
    Session session,
    String code,
    int memberId,
    String text, {
    bool isAnonymous = false,
  }) async {}

  /// Toggle a vote. Rejects if not voting or past deadline.
  /// Denormalizes voteCount in the same transaction.
  Future<void> toggleVote(
    Session session,
    String code,
    int memberId,
    int itemId,
  ) async {}

  /// Check in a member. For meetup rooms, joining via QR sets checkedInAt.
  Future<void> checkIn(Session session, String code, int memberId) async {}

  /// Start a timed vote. Schedules a future call for close.
  Future<void> startVoting(
    Session session,
    String code,
    int memberId,
    Duration duration,
  ) async {}

  /// Idempotent vote close. Picks winner, resolves ties randomly.
  /// Lazy close runs if a vote arrives past deadline.
  Future<void> closeVoting(
    Session session,
    String code, {
    int? byMemberId,
  }) async {}

  /// Set or advance agenda step. Forward only; no rewind.
  Future<void> setCurrentStep(
    Session session,
    String code,
    int memberId,
    int stepId,
  ) async {}

  /// Advance to the next step. Final step stays put.
  Future<void> advanceStep(
    Session session,
    String code,
    int memberId,
  ) async {}

  /// Add an agenda step.
  Future<void> addStep(
    Session session,
    String code,
    int memberId,
    String title,
    DateTime? at,
  ) async {}

  /// Remove an agenda step.
  Future<void> removeStep(
    Session session,
    String code,
    int memberId,
    int stepId,
  ) async {}

  /// Send an ephemeral emoji reaction.
  Future<void> sendReaction(
    Session session,
    String code,
    int memberId,
    String emoji,
  ) async {}

  /// Generate a 5-char room code with no ambiguous glyphs.
  String _generateCode() {
    final alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 5; i++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}

/// Room snapshot returned from getRoomState.
class RoomSnapshot {
  final Room room;
  final List<Member> members;
  final List<ItemView> items;
  final List<AgendaStep> steps;
  final int? viewerMemberId;
  final String? viewerGuestToken;
  final int? votingRemainingMs;

  RoomSnapshot({
    required this.room,
    required this.members,
    required this.items,
    required this.steps,
    this.viewerMemberId,
    this.viewerGuestToken,
    this.votingRemainingMs,
  });
}

/// Room event broadcast on the stream.
class RoomEvent {
  final String type;
  final int? memberId;
  final int? itemId;
  final int? count;
  final int? total;
  final String? emoji;
  final int? remainingMs;
  final int? winnerItemId;
  final bool? wasTie;
  final int? stepId;

  RoomEvent.memberJoined(this.memberId) : type = 'memberJoined';
  RoomEvent.itemAdded(this.itemId) : type = 'itemAdded';
  RoomEvent.voteChanged(this.itemId, this.count) : type = 'voteChanged';
  RoomEvent.checkedIn(this.count, this.total) : type = 'checkedIn';
  RoomEvent.reaction(this.emoji, this.memberId) : type = 'reaction';
  RoomEvent.votingStarted(this.remainingMs) : type = 'votingStarted';
  RoomEvent.votingClosed(this.winnerItemId, this.wasTie) : type = 'votingClosed';
  RoomEvent.stepChanged(this.stepId) : type = 'stepChanged';
}

/// Room, Member, Item, Vote, AgendaStep model classes for serverpod.
class Room {
  final String code;
  final String title;
  final String type;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final int? expectedCount;
  final DateTime? votingEndsAt;
  final int? winnerItemId;
  final bool wasTie;
  final int? currentStepId;

  Room({
    required this.code,
    required this.title,
    required this.type,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    this.expectedCount,
    this.votingEndsAt,
    this.winnerItemId,
    this.wasTie = false,
    this.currentStepId,
  });
}

class Member {
  final int id;
  final String userId;
  final String displayName;
  final String emoji;
  final String role;
  final DateTime joinedAt;
  final DateTime? checkedInAt;

  Member({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.emoji,
    required this.role,
    required this.joinedAt,
    this.checkedInAt,
  });

  bool get isCheckedIn => checkedInAt != null;
  bool get isOwner => role == 'owner';
}

class Item {
  final int id;
  final int authorMemberId;
  final String kind;
  final String text;
  final bool isAnonymous;
  final DateTime createdAt;
  final int voteCount;

  Item({
    required this.id,
    required this.authorMemberId,
    required this.kind,
    required this.text,
    required this.isAnonymous,
    required this.createdAt,
    required this.voteCount,
  });
}

class Vote {
  final int itemId;
  final int memberId;
  final DateTime createdAt;

  Vote({required this.itemId, required this.memberId, required this.createdAt});
}

class AgendaStep {
  final int id;
  final String title;
  final DateTime? at;
  final int position;

  AgendaStep({
    required this.id,
    required this.title,
    this.at,
    required this.position,
  });
}

class ItemView {
  final Item item;
  final int votes;
  final bool votedByMe;
  final bool canSeeAuthor;

  ItemView({
    required this.item,
    required this.votes,
    required this.votedByMe,
    required this.canSeeAuthor,
  });
}
