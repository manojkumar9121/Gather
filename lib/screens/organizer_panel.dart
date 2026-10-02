import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/deep_links.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import '../state/room_controller.dart';
import '../theme.dart';

/// Organizer-only controls. Everything here is enforced again in the
/// repository, so a stale client cannot get around the rules.
class OrganizerPanel extends StatefulWidget {
  const OrganizerPanel({
    super.key,
    required this.controller,
    required this.snapshot,
  });

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  State<OrganizerPanel> createState() => _OrganizerPanelState();
}

class _OrganizerPanelState extends State<OrganizerPanel> {
  final _stepController = TextEditingController();

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final room = snapshot.room;
    final template = templateFor(room.type);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: GatherColors.offWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.md,
              Gap.lg,
              Gap.xxl + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: GatherColors.muted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              const _Heading('Room code'),
              const SizedBox(height: Gap.sm),
              _CodeCard(code: room.code),
              const SizedBox(height: Gap.lg),
              const _Heading('Voting'),
              const SizedBox(height: Gap.sm),
              if (room.isVoting)
                _VotingOpen(controller: widget.controller)
              else
                _VotingClosed(
                  controller: widget.controller,
                  snapshot: snapshot,
                ),
              const SizedBox(height: Gap.lg),
              _Heading('${template.agendaLabel} plan'),
              const SizedBox(height: Gap.xs),
              Text(
                'Everyone in the room sees the current step on their Now tab.',
                style: TextStyle(
                  color: GatherColors.muted.withValues(alpha: 1),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: Gap.md),
              // The room's position only ever moves forward, and the pointer
              // stops on the last step, so this disables rather than failing
              // on the final tap.
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: snapshot.isAtEndOfPlan
                      ? GatherColors.muted
                      : GatherColors.ultramarine,
                ),
                onPressed: snapshot.isAtEndOfPlan
                    ? null
                    : () => widget.controller.advanceStep(),
                icon: Icon(
                  snapshot.isAtEndOfPlan
                      ? Icons.flag_rounded
                      : Icons.skip_next_rounded,
                ),
                label: Text(
                  snapshot.isAtEndOfPlan
                      ? "That's the end of the plan"
                      : 'Move everyone to the next step',
                ),
              ),
              const SizedBox(height: Gap.md),
              if (snapshot.steps.isEmpty)
                const Text(
                  'No steps yet. Add the first one below.',
                  style: TextStyle(color: GatherColors.muted),
                ),
              for (final step in snapshot.steps)
                _StepControl(
                  title: step.title,
                  isCurrent: room.currentStepId == step.id,
                  onMakeCurrent: () =>
                      widget.controller.setCurrentStep(step.id),
                  onDelete: () => widget.controller.removeStep(step.id),
                ),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Add a step',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  SizedBox(
                    width: kTapTarget,
                    height: kTapTarget,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final title = _stepController.text.trim();
                        if (title.isEmpty) return;
                        _stepController.clear();
                        widget.controller.addStep(title);
                      },
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  String get deepLink => joinLink(code);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: GatherColors.ultramarine,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SHARE THIS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: GatherColors.gold,
            ),
          ),
          const SizedBox(height: Gap.md),
          Center(
            child: Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: deepLink,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: GatherColors.ultramarineInk,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: GatherColors.ultramarineInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54, width: 2),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: deepLink));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Invite link copied'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Copy invite link'),
          ),
        ],
      ),
    );
  }
}

class _VotingOpen extends StatelessWidget {
  const _VotingOpen({required this.controller});

  final RoomController controller;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.secondsLeft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: GatherColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 20),
              const SizedBox(width: Gap.sm),
              Text(
                seconds == null ? 'Voting is open' : 'Closes in ${seconds}s',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          onPressed: () => controller.closeVoting(),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Close voting now'),
        ),
      ],
    );
  }
}

class _VotingClosed extends StatefulWidget {
  const _VotingClosed({required this.controller, required this.snapshot});

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  State<_VotingClosed> createState() => _VotingClosedState();
}

class _VotingClosedState extends State<_VotingClosed> {
  static const _durations = [
    (label: '30 sec', value: Duration(seconds: 30)),
    (label: '1 min', value: Duration(minutes: 1)),
    (label: '2 min', value: Duration(minutes: 2)),
    (label: '5 min', value: Duration(minutes: 5)),
  ];

  Duration _selected = _durations[1].value;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.snapshot.room.isClosed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDone)
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: GatherColors.muted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'This vote has closed. Start a new one from the Items tab.',
              style: TextStyle(color: GatherColors.muted, height: 1.35),
            ),
          )
        else ...[
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final option in _durations)
                ChoiceChip(
                  label: Text(option.label),
                  selected: _selected == option.value,
                  onSelected: (_) => setState(() => _selected = option.value),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            onPressed: () => widget.controller.startVoting(_selected),
            icon: const Icon(Icons.how_to_vote_rounded),
            label: Text(
              'Start ${_durations.firstWhere((d) => d.value == _selected).label} vote',
            ),
          ),
        ],
      ],
    );
  }
}

class _StepControl extends StatelessWidget {
  const _StepControl({
    required this.title,
    required this.isCurrent,
    required this.onMakeCurrent,
    required this.onDelete,
  });

  final String title;
  final bool isCurrent;
  final VoidCallback onMakeCurrent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.xs, Gap.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? GatherColors.goldDeep : GatherColors.muted,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrent)
              const Text(
                'NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: GatherColors.goldDeep,
                ),
              )
            else
              TextButton(onPressed: onMakeCurrent, child: const Text('Go here')),
            IconButton(
              tooltip: 'Remove step',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
