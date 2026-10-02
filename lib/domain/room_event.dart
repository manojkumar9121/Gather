/// The single room event type, matching the plan's `RoomEvent`. One
/// serializable class with a `type` and an optional payload, so the local
/// prototype and the eventual Serverpod stream send the identical shape.
enum RoomEventType {
  memberJoined,
  itemAdded,
  voteChanged,
  checkedIn,
  reaction,
  votingStarted,
  votingClosed,
  stepChanged,
}

class RoomEvent {
  const RoomEvent(
    this.type, {
    this.memberId,
    this.itemId,
    this.count,
    this.total,
    this.emoji,
    this.remainingMs,
    this.winnerItemId,
    this.wasTie,
    this.stepId,
  });

  const RoomEvent.memberJoined(int memberId)
    : this(RoomEventType.memberJoined, memberId: memberId);

  const RoomEvent.itemAdded(int itemId)
    : this(RoomEventType.itemAdded, itemId: itemId);

  const RoomEvent.voteChanged(int itemId, int count)
    : this(RoomEventType.voteChanged, itemId: itemId, count: count);

  const RoomEvent.checkedIn(int count, int total)
    : this(RoomEventType.checkedIn, count: count, total: total);

  const RoomEvent.reaction(String emoji, int memberId)
    : this(
        RoomEventType.reaction,
        emoji: emoji,
        memberId: memberId,
      );

  const RoomEvent.votingStarted(int remainingMs)
    : this(RoomEventType.votingStarted, remainingMs: remainingMs);

  const RoomEvent.votingClosed(int? winnerItemId, bool wasTie)
    : this(
        RoomEventType.votingClosed,
        winnerItemId: winnerItemId,
        wasTie: wasTie,
      );

  const RoomEvent.stepChanged(int stepId)
    : this(RoomEventType.stepChanged, stepId: stepId);

  final RoomEventType type;
  final int? memberId;
  final int? itemId;
  final int? count;
  final int? total;
  final String? emoji;

  /// Milliseconds left, measured on the server. Clients anchor to this rather
  /// than subtracting from their own `DateTime.now()`, which would be wrong on
  /// any phone whose clock is off.
  final int? remainingMs;
  final int? winnerItemId;
  final bool? wasTie;
  final int? stepId;

  @override
  String toString() => 'RoomEvent(${type.name})';
}

/// Raised when a room rule rejects an action. Today these are enforced in the
/// local repository; once the server exists they come back as server errors
/// with the same message, so the UI surfaces them unchanged.
class GatherRuleException implements Exception {
  const GatherRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}
