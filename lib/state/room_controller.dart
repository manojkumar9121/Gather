import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/room_repository.dart';
import '../domain/room_event.dart';
import '../domain/room_snapshot.dart';

/// A reaction in flight. Reactions are never stored, so this list is
/// deliberately short-lived and rebuilt from nothing on every join.
class LiveReaction {
  LiveReaction(this.emoji, this.memberId, this.sentAt)
    : id = '$memberId-${sentAt.microsecondsSinceEpoch}';

  final String id;
  final String emoji;
  final int memberId;
  final DateTime sentAt;
}

/// Holds the room the UI renders from, and is the only thing that talks to
/// [RoomRepository].
///
/// The controller re-reads the full snapshot whenever an event arrives rather
/// than trying to patch state per event. Slightly more work, but it cannot
/// drift out of sync with the source of truth, and it behaves identically once
/// the repository is remote.
class RoomController extends ChangeNotifier {
  RoomController(this._repository);

  final RoomRepository _repository;

  RoomSnapshot? _snapshot;
  RoomSnapshot? get snapshot => _snapshot;

  String? _code;
  String? get code => _code;

  String? _error;
  String? get error => _error;

  bool _busy = false;
  bool get busy => _busy;

  final List<LiveReaction> _reactions = [];
  List<LiveReaction> get reactions => List.unmodifiable(_reactions);

  StreamSubscription<RoomEvent>? _eventSub;
  Timer? _ticker;

  /// Bumped once a second while voting so countdowns repaint without every
  /// screen owning its own timer.
  DateTime _now = DateTime.now();
  DateTime get now => _now;

  /// Opens a room: fetch the snapshot first, then subscribe. The fetch is what
  /// makes a late join or a phone waking from sleep land in the right state.
  Future<void> open(String code, {int? viewerMemberId}) async {
    _code = code;
    _viewerMemberId = viewerMemberId;
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      _snapshot = await _repository.getRoomState(
        code,
        viewerMemberId: viewerMemberId,
      );
      await _eventSub?.cancel();
      _eventSub = _repository.events(code).listen(_onEvent);
      _syncTicker();
    } on GatherRuleException catch (e) {
      _error = e.message;
      _snapshot = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Re-binds the viewer, e.g. after storing a member id for a rejoining guest.
  Future<void> setViewer(int memberId) async {
    _viewerMemberId = memberId;
    await refresh();
  }

  int? _viewerMemberId;
  int? get viewerMemberId => _viewerMemberId;

  Future<void> refresh() async {
    final code = _code;
    if (code == null) return;
    try {
      _snapshot = await _repository.getRoomState(
        code,
        viewerMemberId: _viewerMemberId,
      );
      _error = null;
    } on GatherRuleException catch (e) {
      _error = e.message;
    }
    _syncTicker();
    notifyListeners();
  }

  void _onEvent(RoomEvent event) {
    // Reactions are the one thing not in the snapshot, so they are handled
    // here and nowhere else.
    if (event.type == RoomEventType.reaction && event.emoji != null) {
      _reactions.add(
        LiveReaction(event.emoji!, event.memberId ?? 0, DateTime.now()),
      );
      if (_reactions.length > 12) _reactions.removeAt(0);
      notifyListeners();
      Timer(const Duration(seconds: 3), () {
        _reactions.removeWhere((r) => r.id.startsWith('${event.memberId}-'));
        notifyListeners();
      });
    }
    unawaited(refresh());
  }

  void _syncTicker() {
    final endsAt = _snapshot?.room.votingEndsAt;
    final needsTicker =
        _snapshot?.room.isVoting == true && endsAt != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _now = DateTime.now();
        notifyListeners();
      });
    } else if (!needsTicker && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Seconds left, or null when not voting. Never negative.
  int? get secondsLeft {
    final endsAt = _snapshot?.room.votingEndsAt;
    if (!_snapshot!.room.isVoting || endsAt == null) return null;
    final left = endsAt.difference(_now).inSeconds;
    return left < 0 ? 0 : left;
  }

  // --- actions ------------------------------------------------------------

  Future<void> addItem(String text, {bool isAnonymous = false}) =>
      _guard(() => _repository.addItem(
        code: _requireCode(),
        memberId: _requireMember(),
        text: text,
        isAnonymous: isAnonymous,
      ));

  Future<void> toggleVote(int itemId) =>
      _guard(() => _repository.toggleVote(
        code: _requireCode(),
        memberId: _requireMember(),
        itemId: itemId,
      ));

  Future<void> checkIn() => _guard(
    () => _repository.checkIn(
      code: _requireCode(),
      memberId: _requireMember(),
    ),
  );

  Future<void> startVoting(Duration duration) => _guard(
    () => _repository.startVoting(
      code: _requireCode(),
      memberId: _requireMember(),
      duration: duration,
    ),
  );

  Future<void> closeVoting() => _guard(
    () => _repository.closeVoting(code: _requireCode(), byMemberId: _requireMember()),
  );

  Future<void> addStep(String title) => _guard(
    () => _repository.addStep(
      code: _requireCode(),
      memberId: _requireMember(),
      title: title,
    ),
  );

  Future<void> removeStep(int stepId) => _guard(
    () => _repository.removeStep(
      code: _requireCode(),
      memberId: _requireMember(),
      stepId: stepId,
    ),
  );

  Future<void> advanceStep() => _guard(
    () => _repository.advanceStep(
      code: _requireCode(),
      memberId: _requireMember(),
    ),
  );

  Future<void> setCurrentStep(int stepId) => _guard(
    () => _repository.setCurrentStep(
      code: _requireCode(),
      memberId: _requireMember(),
      stepId: stepId,
    ),
  );

  Future<void> setStepDone(int stepId, bool isDone) => _guard(
    () => _repository.setStepDone(
      code: _requireCode(),
      stepId: stepId,
      isDone: isDone,
    ),
  );

  /// Fire and forget: a reaction must never show an error, since it changes
  /// nothing about room state.
  Future<void> react(String emoji) async {
    try {
      await _repository.sendReaction(
        code: _requireCode(),
        memberId: _requireMember(),
        emoji: emoji,
      );
    } on GatherRuleException {
      // Nothing to do. Reactions are best-effort by design.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    _error = null;
    try {
      await action();
      await refresh();
    } on GatherRuleException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  String _requireCode() {
    final code = _code;
    if (code == null) {
      throw const GatherRuleException('You are not in a room yet.');
    }
    return code;
  }

  int _requireMember() {
    final id = _viewerMemberId;
    if (id == null) {
      throw const GatherRuleException('You are not in a room yet.');
    }
    return id;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
