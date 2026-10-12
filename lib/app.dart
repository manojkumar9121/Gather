import 'dart:async';

import 'package:flutter/material.dart';

import 'data/deep_links.dart';
import 'data/guest_identity.dart';
import 'data/local_room_repository.dart';
import 'data/room_repository.dart';
import 'screens/join_screen.dart';
import 'screens/landing_screen.dart';
import 'theme.dart';

class GatherApp extends StatefulWidget {
  const GatherApp({super.key});

  @override
  State<GatherApp> createState() => _GatherAppState();
}

class _GatherAppState extends State<GatherApp> with WidgetsBindingObserver {
  // One repository for the app's lifetime. Swapping this for a Serverpod-backed
  // implementation is the only change the backend requires.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final RoomRepository _repository;

  final GuestIdentityStore _identityStore = GuestIdentityStore();
  final GatherDeepLinks _deepLinks = GatherDeepLinks();

  GuestIdentity? _identity;
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Saving a name or a room has to reach the landing screen, otherwise
    // "back into your room" only appears after a restart.
    _identityStore.addListener(_onIdentityChanged);
    _repository = LocalRoomRepository(
      onSchemaMismatch: () {
        // A schema bump means stored rooms will be cleared. Show a brief banner
        // so the user isn't surprised by lost state. This is best-effort; if the
        // navigator isn't ready yet the callback simply does nothing.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = _navigatorKey.currentState;
          if (navigator == null) return;
          ScaffoldMessenger.of(navigator.context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your local room data was cleared due to an app update. '
                'Create a new room to continue.',
              ),
            ),
          );
        });
      },
    );
    _bootstrap();
  }

  void _onIdentityChanged() {
    if (!mounted) return;
    setState(() => _identity = _identityStore.current);
  }

  Future<void> _bootstrap() async {
    // A link that cold-launches the app is only delivered to a listener that
    // already exists, so the deep-link subscription starts before anything
    // else can route.
    _deepLinks.start();
    _linkSub = _deepLinks.codes.listen(_openJoinFor);

    final identity = await _identityStore.load();
    if (!mounted) return;
    setState(() => _identity = identity);

    final launchCode = await _deepLinks.initialCode();
    if (launchCode != null) {
      _openJoinFor(launchCode);
    }
  }

  void _openJoinFor(String code) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => JoinScreen(
          initialCode: code,
          identity: _identity,
          identityStore: _identityStore,
          viaQr: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _identityStore.removeListener(_onIdentityChanged);
    _linkSub?.cancel();
    _deepLinks.dispose();
    // Only the local implementation owns timers and subscriptions. Checked rather
    // than cast so swapping in a Serverpod repository -- the change this file
    // exists to make easy -- does not throw on teardown.
    final repo = _repository;
    if (repo is LocalRoomRepository) repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: _repository,
      child: IdentityScope(
        identity: _identity,
        store: _identityStore,
        child: MaterialApp(
          title: 'Gather',
          debugShowCheckedModeBanner: false,
          theme: buildGatherTheme(),
          navigatorKey: _navigatorKey,
          home: const LandingScreen(),
        ),
      ),
    );
  }
}

/// Exposes the one [RoomRepository] the app runs on. Screens read it rather
/// than constructing a repository, so swapping in a Serverpod-backed
/// implementation touches this file and nothing else.
class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final RoomRepository repository;

  static RoomRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No repository found in the widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      oldWidget.repository != repository;
}

/// Exposes the stored guest identity. Null until storage has answered, so
/// screens must handle the brief "we do not know this phone yet" state.
class IdentityScope extends InheritedWidget {
  const IdentityScope({
    super.key,
    required this.identity,
    required this.store,
    required super.child,
  });

  final GuestIdentity? identity;
  final GuestIdentityStore store;

  static IdentityScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IdentityScope>();
    assert(scope != null, 'No identity scope found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(IdentityScope oldWidget) =>
      oldWidget.identity != identity;
}
