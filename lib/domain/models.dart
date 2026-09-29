/// Core domain models. These mirror the plan's Serverpod `.spy.yaml` models so
/// that the local prototype and the eventual backend agree on shape.
library;

/// The three room templates. Adding a type is a new enum value plus a config
/// entry in `room_template.dart`; it is not a new architecture.
enum RoomType {
  meetup('meetup'),
  trip('trip'),
  movie('movie');

  const RoomType(this.wireName);

  final String wireName;

  static RoomType fromWire(String value) =>
      RoomType.values.firstWhere((t) => t.wireName == value);
}

enum RoomStatus {
  open('open'),
  voting('voting'),
  closed('closed');

  const RoomStatus(this.wireName);

  final String wireName;

  static RoomStatus fromWire(String value) =>
      RoomStatus.values.firstWhere((t) => t.wireName == value);
}

enum MemberRole {
  owner('owner'),
  guest('guest');

  const MemberRole(this.wireName);

  final String wireName;

  static MemberRole fromWire(String value) =>
      MemberRole.values.firstWhere((t) => t.wireName == value);
}

/// What an item is, set at creation time from the room template so the client
/// can label things correctly even before the room config loads.
enum ItemKind {
  question('question'),
  suggestion('suggestion'),
  stop('stop');

  const ItemKind(this.wireName);

  final String wireName;

  static ItemKind fromWire(String value) =>
      ItemKind.values.firstWhere((t) => t.wireName == value);
}

class Room {
  const Room({
    required this.code,
    required this.title,
    required this.type,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.expectedCount,
    required this.winnerItemId,
    required this.wasTie,
    this.votingEndsAt,
    this.currentStepId,
  });

  final String code;
  final String title;
  final RoomType type;

  /// Identity of the organizer. A local id for the prototype, a Serverpod
  /// user id once auth lands.
  final String ownerId;
  final RoomStatus status;
  final DateTime createdAt;

  /// Denominator for the "12 of 20 here" counter. Null when the organizer has
  /// not set an expected size.
  final int? expectedCount;

  final DateTime? votingEndsAt;
  final int? winnerItemId;
  final bool wasTie;

  /// The one agenda step the room is on right now. Steps before it are done,
  /// steps after it are upcoming. Null means the room has not started moving.
  final int? currentStepId;

  bool get isVoting => status == RoomStatus.voting;
  bool get isClosed => status == RoomStatus.closed;

  Room copyWith({
    RoomStatus? status,
    DateTime? votingEndsAt,
    int? winnerItemId,
    bool? wasTie,
    int? currentStepId,
    int? expectedCount,
  }) {
    return Room(
      code: code,
      title: title,
      type: type,
      ownerId: ownerId,
      status: status ?? this.status,
      createdAt: createdAt,
      expectedCount: expectedCount ?? this.expectedCount,
      votingEndsAt: votingEndsAt ?? this.votingEndsAt,
      winnerItemId: winnerItemId ?? this.winnerItemId,
      wasTie: wasTie ?? this.wasTie,
      currentStepId: currentStepId ?? this.currentStepId,
    );
  }

  /// `copyWith` cannot null out a field, and deleting the current step needs
  /// to clear the pointer, so that case gets its own method.
  Room withCurrentStep(int? stepId) {
    return Room(
      code: code,
      title: title,
      type: type,
      ownerId: ownerId,
      status: status,
      createdAt: createdAt,
      expectedCount: expectedCount,
      votingEndsAt: votingEndsAt,
      winnerItemId: winnerItemId,
      wasTie: wasTie,
      currentStepId: stepId,
    );
  }
}

class Member {
  const Member({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.emoji,
    required this.role,
    required this.joinedAt,
    this.checkedInAt,
  });

  final int id;

  /// The owning account, or a guest id. For a guest this is a locally
  /// generated device identity, so rejoining a room maps to the same member.
  final String userId;
  final String displayName;
  final String emoji;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? checkedInAt;

  bool get isCheckedIn => checkedInAt != null;
  bool get isOwner => role == MemberRole.owner;
}

class Item {
  const Item({
    required this.id,
    required this.authorMemberId,
    required this.kind,
    required this.text,
    required this.isAnonymous,
    required this.createdAt,
  });

  final int id;
  final int authorMemberId;
  final ItemKind kind;
  final String text;
  final bool isAnonymous;
  final DateTime createdAt;
}

class Vote {
  const Vote({
    required this.itemId,
    required this.memberId,
    required this.createdAt,
  });

  final int itemId;
  final int memberId;
  final DateTime createdAt;
}

/// One step in the room's shared agenda.
class AgendaStep {
  const AgendaStep({
    required this.id,
    required this.title,
    required this.position,
    required this.isDone,
    this.at,
  });

  final int id;
  final String title;

  /// Optional wall-clock hint, e.g. "break at 9:30". Not an enforcement
  /// deadline; the room's real clock lives on [Room.votingEndsAt].
  final DateTime? at;
  final int position;
  final bool isDone;

  AgendaStep copyWith({bool? isDone, int? position}) {
    return AgendaStep(
      id: id,
      title: title,
      at: at,
      position: position ?? this.position,
      isDone: isDone ?? this.isDone,
    );
  }
}

/// Where a step sits relative to the room's current pointer. Named to avoid
/// colliding with Flutter's own `StepState` from the stepper widget.
enum AgendaStepState { done, current, upcoming }
