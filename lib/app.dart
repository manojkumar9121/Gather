import 'package:flutter/material.dart';

import 'data/local_room_repository.dart';
import 'data/room_repository.dart';
import 'screens/landing_screen.dart';
import 'theme.dart';

class GatherApp extends StatefulWidget {
  const GatherApp({super.key});

  @override
  State<GatherApp> createState() => _GatherAppState();
}

class _GatherAppState extends State<GatherApp> {
  // One repository for the app's lifetime. Swapping this for a Serverpod-backed
  // implementation is the only change the backend requires.
  final RoomRepository _repository = LocalRoomRepository();

  @override
  void dispose() {
    (_repository as LocalRoomRepository).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: _repository,
      child: MaterialApp(
        title: 'Gather',
        debugShowCheckedModeBanner: false,
        theme: buildGatherTheme(),
        home: const LandingScreen(),
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
    final scope =
        context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No repository found in the widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      oldWidget.repository != repository;
}
