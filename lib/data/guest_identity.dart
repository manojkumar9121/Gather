import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the phone remembers between launches.
///
/// This is the whole of persistence. A hackathon does not need more, and the
/// plan deliberately stops here: no Hive, no Isar, no database for four keys.
class GuestIdentity {
  const GuestIdentity({
    required this.guestId,
    required this.displayName,
    required this.emoji,
    required this.lastRoomCode,
  });

  final String guestId;
  final String? displayName;
  final String? emoji;

  /// Lets the app offer "back into the room" instead of an empty code field
  /// after a restart.
  final String? lastRoomCode;

  bool get hasName => (displayName ?? '').trim().isNotEmpty;

  GuestIdentity copyWith({
    String? guestId,
    String? displayName,
    String? emoji,
    String? lastRoomCode,
    bool clearRoom = false,
  }) {
    return GuestIdentity(
      guestId: guestId ?? this.guestId,
      displayName: displayName ?? this.displayName,
      emoji: emoji ?? this.emoji,
      lastRoomCode: clearRoom ? null : (lastRoomCode ?? this.lastRoomCode),
    );
  }
}

/// Reads and writes [GuestIdentity].
///
/// The `guestId` is generated once per install and is the token the server
/// hands back a member for. Losing it means a returning phone looks like a new
/// person, which is exactly what the check-in counter must not do.
class GuestIdentityStore extends ChangeNotifier {
  static const _kGuestId = 'gather.guestId';
  static const _kName = 'gather.displayName';
  static const _kEmoji = 'gather.emoji';
  static const _kLastRoom = 'gather.lastRoomCode';

  GuestIdentity? _current;

  /// The identity as last loaded or saved. Null until [load] has answered.
  GuestIdentity? get current => _current;

  /// RFC 4122 version 4 shape, generated without a package.
  static String _uuid(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<GuestIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    var guestId = prefs.getString(_kGuestId);
    if (guestId == null || guestId.isEmpty) {
      guestId = _uuid(Random.secure());
      await prefs.setString(_kGuestId, guestId);
    }
    final identity = GuestIdentity(
      guestId: guestId,
      displayName: prefs.getString(_kName),
      emoji: prefs.getString(_kEmoji),
      lastRoomCode: prefs.getString(_kLastRoom),
    );
    _current = identity;
    return identity;
  }

  Future<void> saveName(String name, String emoji) async {
    // The in-memory copy moves first. The UI should not wait on a disk write to
    // show what the user just did.
    _update((current) => current.copyWith(displayName: name, emoji: emoji));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kEmoji, emoji);
  }

  Future<void> saveLastRoom(String code) async {
    _update((current) => current.copyWith(lastRoomCode: code));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastRoom, code);
  }

  Future<void> clearLastRoom() async {
    _update((current) => current.copyWith(clearRoom: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastRoom);
  }

  /// Keeps the in-memory copy in step with what was just written, so anything
  /// listening sees the new value without waiting for a restart. Without this
  /// the landing screen keeps showing a stale "back into your room" for the
  /// whole session, because the app only reads the identity once at startup.
  void _update(GuestIdentity Function(GuestIdentity current) change) {
    final current = _current;
    if (current == null) return;
    _current = change(current);
    notifyListeners();
  }
}
