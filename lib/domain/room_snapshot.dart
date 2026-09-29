import 'models.dart';

/// An item plus the derived state a client needs to render it: its live vote
/// count, and whether the current member has voted for it.
class ItemView {
  const ItemView({
    required this.item,
    required this.votes,
    required this.votedByMe,
  });

  final Item item;
  final int votes;
  final bool votedByMe;

  ItemView copyWith({int? votes, bool? votedByMe}) {
    return ItemView(
      item: item,
      votes: votes ?? this.votes,
      votedByMe: votedByMe ?? this.votedByMe,
    );
  }
}

/// The full room as the server would return it from `getRoomState(code)`.
/// Clients fetch this first, then subscribe to the stream. A phone that
/// sleeps and reconnects needs exactly this, or it renders an empty room.
class RoomSnapshot {
  const RoomSnapshot({
    required this.room,
    required this.members,
    required this.items,
    required this.steps,
    required this.viewerMemberId,
  });

  final Room room;
  final List<Member> members;
  final List<ItemView> items;
  final List<AgendaStep> steps;

  /// Which member this snapshot is being rendered for.
  final int? viewerMemberId;

  int get checkedInCount => members.where((m) => m.isCheckedIn).length;
  int get totalMembers => members.length;

  Member? get viewer {
    if (viewerMemberId == null) return null;
    for (final m in members) {
      if (m.id == viewerMemberId) return m;
    }
    return null;
  }

  Member? memberById(int? id) {
    if (id == null) return null;
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  AgendaStep? get currentStep {
    final id = room.currentStepId;
    if (id == null) return null;
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  AgendaStep? get nextStep {
    final current = currentStep;
    if (current == null) return steps.isEmpty ? null : steps.first;
    for (final s in steps) {
      if (s.position == current.position + 1) return s;
    }
    return null;
  }

  /// Where a step sits relative to the room's current pointer.
  AgendaStepState stateFor(AgendaStep step) {
    final current = room.currentStepId;
    if (step.isDone) return AgendaStepState.done;
    if (current == null) {
      return step.position == 0
          ? AgendaStepState.current
          : AgendaStepState.upcoming;
    }
    if (step.id == current) return AgendaStepState.current;
    for (final s in steps) {
      if (s.id == current) {
        return step.position < s.position
            ? AgendaStepState.done
            : AgendaStepState.upcoming;
      }
    }
    return AgendaStepState.upcoming;
  }

  /// Index of the current step, for the progress bar. Zero when the room has
  /// not started.
  int get currentStepIndex {
    final current = currentStep;
    if (current == null) return 0;
    return steps.indexWhere((s) => s.id == current.id).clamp(0, steps.length);
  }

  ItemView? get winner {
    final id = room.winnerItemId;
    if (id == null) return null;
    for (final view in items) {
      if (view.item.id == id) return view;
    }
    return null;
  }

  /// Items ordered by votes for the reveal and the results list.
  List<ItemView> get rankedItems {
    final copy = [...items];
    copy.sort((a, b) {
      final byVotes = b.votes.compareTo(a.votes);
      if (byVotes != 0) return byVotes;
      return a.item.id.compareTo(b.item.id);
    });
    return copy;
  }
}
