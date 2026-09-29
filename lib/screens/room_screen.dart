import 'package:flutter/material.dart';

import '../app.dart';
import '../domain/room_snapshot.dart';
import '../state/room_controller.dart';
import '../theme.dart';
import 'items_tab.dart';
import 'now_tab.dart';
import 'organizer_panel.dart';
import 'people_tab.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.code,
    required this.viewerMemberId,
  });

  final String code;
  final int? viewerMemberId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomController? _controller;
  String? _lastError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = RoomController(RepositoryScope.of(context));
    controller.addListener(_onControllerChanged);
    _controller = controller;
    controller.open(widget.code, viewerMemberId: widget.viewerMemberId);
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    final error = controller.error;
    if (error != null && error != _lastError) {
      _lastError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: GatherColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;

        if (snapshot == null) {
          return _RoomShell(
            title: 'Gathering',
            child: _MissingRoom(
              message:
                  controller.error ??
                  "We couldn't find that room. Check the code and try again.",
              onRetry: () =>
                  controller.open(widget.code, viewerMemberId: widget.viewerMemberId),
            ),
          );
        }

        return _RoomShell(
          title: snapshot.room.title,
          snapshot: snapshot,
          controller: controller,
        );
      },
    );
  }
}
class _RoomShell extends StatelessWidget {
  const _RoomShell({
    required this.title,
    this.child,
    this.snapshot,
    this.controller,
  });

  final String title;

  /// Shown when there is no room to render. When [snapshot] is present the
  /// shell builds the tabbed body itself.
  final Widget? child;
  final RoomSnapshot? snapshot;
  final RoomController? controller;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: child ?? const SizedBox.shrink(),
      );
    }

    final room = snapshot!.room;
    final viewer = snapshot!.viewer;
    final isOwner = viewer?.isOwner ?? false;
    final templateLabel = room.type.name;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                'Room ${room.code} · $templateLabel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: GatherColors.muted,
                ),
              ),
            ],
          ),
          actions: [
            if (isOwner && controller != null)
              IconButton(
                tooltip: 'Organizer panel',
                icon: const Icon(Icons.tune),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => OrganizerPanel(
                    controller: controller!,
                    snapshot: snapshot!,
                  ),
                ),
              ),
          ],
          bottom: const TabBar(
            indicatorColor: GatherColors.gold,
            indicatorWeight: 3,
            labelColor: GatherColors.ultramarine,
            unselectedLabelColor: GatherColors.muted,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            tabs: [
              Tab(text: 'Now'),
              Tab(text: 'Items'),
              Tab(text: 'People'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (controller != null) VotingBanner(controller: controller!),
            Expanded(
              child: TabBarView(
                children: [
                  NowTab(controller: controller!, snapshot: snapshot!),
                  ItemsTab(controller: controller!, snapshot: snapshot!),
                  PeopleTab(snapshot: snapshot!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown. Hidden votes are the plan's reveal moment, so the last ten
/// seconds switch to the gold accent.
class VotingBanner extends StatelessWidget {
  const VotingBanner({super.key, required this.controller});

  final RoomController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot!;
    if (!snapshot.room.isVoting) return const SizedBox.shrink();

    final seconds = controller.secondsLeft ?? 0;
    final isFinalSeconds = seconds <= 10;

    return Container(
      width: double.infinity,
      color: isFinalSeconds ? GatherColors.gold : GatherColors.ultramarine,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              isFinalSeconds ? 'Voting closes…' : 'Voting is open',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            _format(seconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }
}

class _MissingRoom extends StatelessWidget {
  const _MissingRoom({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: Gap.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4, color: GatherColors.ultramarineInk),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
