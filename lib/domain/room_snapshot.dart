import 'models.dart';

/// An item plus the derived state a client needs to render it: its live vote
/// count, whether the current member has voted for it, and whether this viewer
/// is allowed to see who wrote it.
class ItemView {
  const ItemView({
    required this.item,
    required this.votes,
    required this.votedByMe,
    required this.canSeeAuthor,
  });

  final Item item;
  final int votes;
  final bool votedByMe;

  /// Guests do not see the author of an anonymous item. The organizer keeps
  /// visibility for moderation.
  final bool canSeeAuthor;

  bool get authorHidden => item.isAnonymous && !canSeeAuthor;
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
    required this.viewerGuestToken,
    required this.votingRemainingMs,
  });

  final Room room;
  final List<Member> members;

  /// Already in the order the server wants it rendered. The client must not
  /// re-sort: the server owns ordering because it owns the freeze.
  final List<ItemView> items;
  final List<AgendaStep> steps;

  final int? viewerMemberId;

  /// The token that gets this member back on a rejoin. For a guest this is
  /// the device-generated identity stored on the phone.
  final String? viewerGuestToken;

  /// Milliseconds left on the vote, measured on the server when this snapshot
  /// was built. Clients anchor to this rather than to their own clock, so a
  /// phone set three minutes fast still sees the same deadline.
  final int? votingRemainingMs;

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

  /// True once the room is on its final step. There is no "past the end"
  /// state: the pointer stays on the last step so "where are we?" always has
  /// an answer, and the advance control disables itself.
  bool get isAtEndOfPlan => currentStep != null && nextStep == null;

  /// Where a step sits relative to the room's current pointer. Derived, never
  /// stored.
  AgendaStepState stateFor(AgendaStep step) {
    final currentId = room.currentStepId;
    if (currentId == null) {
      return step.position == 0
          ? AgendaStepState.current
          : AgendaStepState.upcoming;
    }
    if (step.id == currentId) return AgendaStepState.current;
    for (final s in steps) {
      if (s.id == currentId) {
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
    final index = steps.indexWhere((s) => s.id == current.id);
    return index < 0 ? 0 : index;
  }

  /// The winner, straight from the room pointer. The server picked it, so the
  /// client never recomputes one; a tie-break spin animates to this item
  /// rather than deciding it, which is what keeps two phones agreeing.
  ItemView? get winner {
    final id = room.winnerItemId;
    if (id == null) return null;
    for (final view in items) {
      if (view.item.id == id) return view;
    }
    return null;
  }

  /// Whether a vote happened at all, which decides between a real reveal and
  /// the designed empty state.
  bool get hasAnyVotes =>
      items.any((i) => i.item.voteCount > 0);
}
