import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/deep_links.dart';
import '../domain/models.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import '../state/room_controller.dart';
import '../theme.dart';
import '../widgets/end_event_button.dart';

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
            color: GatherColors.blackBase,
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
                    color: const Color(0x3FFFFFFF),
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
                  color: GatherColors.mutedText.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Gap.md),
              // At the final step, show a "Complete plan" button.
              // Before the final step, advance moves the pointer forward.
              // An empty plan has nothing to advance to and nothing to complete, so
              // neither button is offered.
              if (snapshot.isEventEnded)
                const _EventEndedNotice()
              else if (snapshot.steps.isEmpty)
                const SizedBox.shrink()
              else if (snapshot.isPlanCompleted) ...[
                const _PlanCompleteButton(),
                const SizedBox(height: Gap.md),
                EndEventButton(controller: widget.controller),
              ] else if (snapshot.isAtEndOfPlan)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GatherColors.auroraGold,
                    foregroundColor: const Color(0xFF221900),
                    elevation: 4,
                    shadowColor: GatherColors.auroraGold.withValues(alpha: 0.5),
                  ),
                  onPressed: () => widget.controller.completePlan(),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Complete plan'),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: GatherColors.auroraBlue,
                    foregroundColor: GatherColors.whiteText,
                  ),
                  onPressed: () => widget.controller.advanceStep(),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Move to next step'),
                ),
              const SizedBox(height: Gap.md),
              if (snapshot.steps.isEmpty)
                Text(
                  'No steps yet. Add the first one below.',
                  style: TextStyle(
                    color: GatherColors.mutedText.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
              for (final step in snapshot.steps)
                _StepControl(
                  title: step.title,
                  state: snapshot.stateFor(step),
                  planComplete: snapshot.isPlanCompleted,
                  onMakeCurrent: () =>
                      widget.controller.setCurrentStep(step.id),
                  onDelete: snapshot.isEventEnded
                      ? null
                      : () => widget.controller.removeStep(step.id),
                ),
              const SizedBox(height: Gap.sm),
              // An ended room is read-only, so the step composer goes away
              // rather than sitting there failing on every tap.
              if (!snapshot.isEventEnded)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stepController,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: GatherColors.whiteText),
                        decoration: InputDecoration(
                          hintText: 'Add a step',
                          hintStyle: TextStyle(
                            color: GatherColors.mutedText.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0x18FFFFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0x1FFFFFFF),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0x1FFFFFFF),
                            ),
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
                          backgroundColor: GatherColors.auroraGold,
                          foregroundColor: const Color(0xFF221900),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          final title = _stepController.text.trim();
                          if (title.isEmpty) return;
                          // Cleared only once the step is accepted. Clearing
                          // first ate the typing on any rejection.
                          await widget.controller.addStep(title);
                          if (widget.controller.error == null) {
                            _stepController.clear();
                          }
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

class _PlanCompleteButton extends StatelessWidget {
  const _PlanCompleteButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GatherColors.auroraGold.withValues(alpha: 0.18),
            GatherColors.blackSurface.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GatherColors.auroraGold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: GatherColors.auroraGold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: GatherColors.auroraGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          const Text(
            'Plan complete — wrap up finished',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: GatherColors.auroraGold,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'The agenda is finished. All steps are marked complete.',
            style: TextStyle(
              color: GatherColors.mutedText.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the plan controls once the room has ended.
class _EventEndedNotice extends StatelessWidget {
  const _EventEndedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: GatherColors.success,
            size: 20,
          ),
          SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'This event has ended. The room is read-only.',
              style: TextStyle(
                color: GatherColors.whiteText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
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
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: GatherColors.whiteText,
      ),
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
        color: GatherColors.blackSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x23FFFFFF)),
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
              color: GatherColors.auroraGold,
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
                  color: GatherColors.blackBase,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: GatherColors.blackBase,
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
              foregroundColor: GatherColors.whiteText,
              side: const BorderSide(color: Color(0x33FFFFFF), width: 1.5),
              backgroundColor: const Color(0x18FFFFFF),
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
            color: GatherColors.auroraGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GatherColors.auroraGold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 20,
                color: GatherColors.auroraGold,
              ),
              const SizedBox(width: Gap.sm),
              Text(
                seconds == null ? 'Voting is open' : 'Closes in ${seconds}s',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GatherColors.whiteText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: GatherColors.whiteText,
            side: const BorderSide(color: Color(0x33FFFFFF)),
            backgroundColor: const Color(0x18FFFFFF),
          ),
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
              color: GatherColors.mutedText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Text(
              'This vote has closed. Start a new one from the Items tab.',
              style: TextStyle(
                color: GatherColors.mutedText.withValues(alpha: 0.85),
                height: 1.35,
                fontSize: 14,
              ),
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
                  backgroundColor: const Color(0x18FFFFFF),
                  selectedColor: GatherColors.auroraGold.withValues(alpha: 0.2),
                  side: const BorderSide(color: Color(0x3FFFFFFF)),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: GatherColors.auroraGold,
              foregroundColor: const Color(0xFF221900),
            ),
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
    required this.state,
    required this.planComplete,
    required this.onMakeCurrent,
    required this.onDelete,
  });

  final String title;
  final AgendaStepState state;
  final bool planComplete;
  final VoidCallback onMakeCurrent;

  /// Null once the event has ended, which hides the remove control rather than
  /// leaving a button that would be refused.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == AgendaStepState.current;
    final isDone = state == AgendaStepState.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.xs, Gap.sm),
        decoration: BoxDecoration(
          color: isCurrent
              ? GatherColors.auroraGold.withValues(alpha: 0.1)
              : isDone
              ? const Color(0x08FFFFFF)
              : const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? GatherColors.auroraGold.withValues(alpha: 0.4)
                : isDone
                ? const Color(0x0AFFFFFF)
                : const Color(0x18FFFFFF),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isDone)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: GatherColors.success,
              )
            else if (isCurrent)
              const Icon(
                Icons.play_circle_rounded,
                size: 18,
                color: GatherColors.auroraGold,
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  color: isDone
                      ? GatherColors.mutedText.withValues(alpha: 0.5)
                      : GatherColors.whiteText,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // The pointer sits on the last step once the plan is complete, so
            // every other step is behind it and "Go here" could only ever fail.
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: GatherColors.auroraGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NOW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: GatherColors.auroraGold,
                  ),
                ),
              )
            else if (!planComplete)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: GatherColors.whiteText.withValues(
                    alpha: 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                ),
                onPressed: onMakeCurrent,
                child: const Text('Go here'),
              ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Remove step',
                icon: const Icon(Icons.close_rounded, size: 20),
                color: GatherColors.mutedText.withValues(alpha: 0.6),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
