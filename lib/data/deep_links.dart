import 'dart:async';

import 'package:app_links/app_links.dart';

/// Receives `gather://join/<CODE>` links.
///
/// This is the third QR concern and the one that gets skipped: generating a QR
/// in the organizer panel and scanning it inside the app are both useless if
/// someone points their stock camera at it and nothing opens. The scheme has to
/// be registered in Info.plist and AndroidManifest.xml *and* something has to
/// be listening, or the tap goes nowhere.
///
/// Register the listener as early as possible. A link that launches the app
/// from cold is delivered once, and only to a listener that already exists.
/// Returns a room code from a `gather://join/CODE` link, a bare five
/// character code, or a full QR payload string.
///
/// The in-app scanner and the OS deep-link handler both come through here, so
/// a QR generated one way and read the other cannot disagree about what a code
/// is. This is a top-level function rather than a method on `GatherDeepLinks`
/// so the scanner can use it without importing the app_links plugin.
/// The link the organizer's QR encodes. Registering the `gather` scheme in
/// Info.plist and AndroidManifest.xml is what makes a stock camera open the
/// app. Built here rather than in the panel so the writer and the reader below
/// can never disagree about what a join link looks like.
String joinLink(String code) => 'gather://join/$code';

String? codeFromQrPayload(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (_isRoomCode(trimmed)) return trimmed.toUpperCase();
  final uri = Uri.tryParse(trimmed);
  return uri == null ? null : parseGatherUri(uri);
}

String? parseGatherUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'gather') return null;

  // Canonical form: gather://join/ABCDE
  if (uri.host.toLowerCase() == 'join') {
    for (final segment in uri.pathSegments) {
      if (_isRoomCode(segment)) return segment.toUpperCase();
    }
    return null;
  }

  // Tolerated shorthand: gather://ABCDE
  if (_isRoomCode(uri.host)) return uri.host.toUpperCase();
  return null;
}

bool _isRoomCode(String value) =>
    value.length == 5 && RegExp(r'^[A-Za-z0-9]{5}$').hasMatch(value);

class GatherDeepLinks {
  GatherDeepLinks({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  /// Room codes arriving after start-up.
  Stream<String> get codes async* {
    yield* _appLinks.uriLinkStream
        .map((uri) => codeFromQrPayload(uri.toString()))
        .where((code) => code != null)
        .cast<String>();
  }

  /// The code that launched the app, if any. Check this once after start-up.
  Future<String?> initialCode() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return codeFromQrPayload(uri?.toString());
    } catch (_) {
      // A platform with no link support, or a launch with no link. Not an
      // error worth surfacing: it just means the app opened normally.
      return null;
    }
  }

  void start() {
    _subscription ??= _appLinks.uriLinkStream.listen((_) {});
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
