import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import '../state/room_controller.dart';
import '../theme.dart';

/// The first tab. Someone opening the room should be able to answer "where are
/// we?" without scrolling, so the current step is the loudest thing here.
class NowTab extends StatelessWidget {
  const NowTab({
    super.key,
    required this.controller,
    required this.snapshot,
  });

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final template = templateFor(snapshot.room.type);
    final current = snapshot.currentStep;
    final next = snapshot.nextStep;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        _CheckInCard(controller: controller, snapshot: snapshot),
        const SizedBox(height: Gap.lg),
        Text(
          template.agendaLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: GatherColors.muted,
          ),
        ),
        const SizedBox(height: Gap.sm),
        _CurrentStepCard(
          template: template,
          current: current,
          next: next,
          index: snapshot.currentStepIndex,
          total: snapshot.steps.length,
        ),
        const SizedBox(height: Gap.lg),
        if (snapshot.steps.isEmpty)
          _EmptyNote(
            message:
                'No plan yet. The organizer can add the steps everyone should '
                'expect.',
          )
        else
          for (final step in snapshot.steps)
            _StepRow(
              step: step,
              state: snapshot.stateFor(step),
              isOwner: snapshot.viewer?.isOwner ?? false,
              onTap: snapshot.viewer?.isOwner ?? false
                  ? () => controller.setCurrentStep(step.id)
                  : null,
              onToggleDone: () => controller.setStepDone(
                step.id,
                !step.isDone,
              ),
            ),
      ],
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.controller, required this.snapshot});

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final template = templateFor(snapshot.room.type);
    final expected = snapshot.room.expectedCount;
    final checkedIn = snapshot.checkedInCount;
    final viewer = snapshot.viewer;
    final alreadyIn = viewer?.isCheckedIn ?? false;

    final headline = expected != null && expected > 0
        ? '$checkedIn of $expected here'
        : '$checkedIn ${checkedIn == 1 ? 'person' : 'people'} here';

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: GatherColors.ultramarine,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: GatherColors.gold, size: 22),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          _Avatars(members: snapshot.members),
          if (!alreadyIn) ...[
            const SizedBox(height: Gap.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: GatherColors.gold,
                foregroundColor: GatherColors.ultramarineInk,
              ),
              onPressed: () => controller.checkIn(),
              icon: const Icon(Icons.how_to_reg_rounded),
              label: Text(template.checkInLabel),
            ),
          ] else ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: GatherColors.success, size: 20),
                const SizedBox(width: Gap.sm),
                Text(
                  "You're checked in",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatars extends StatelessWidget {
  const _Avatars({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text(
        'Nobody here yet. Share the code to get people in.',
        style: TextStyle(color: GatherColors.offWhite, fontSize: 14),
      );
    }

    final present = members.where((m) => m.isCheckedIn).toList();
    final shown = (present.isEmpty ? members : present).take(8).toList();

    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final member in shown)
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: member.isCheckedIn
                  ? GatherColors.gold
                  : Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(member.emoji, style: const TextStyle(fontSize: 19)),
          ),
        if ((present.isEmpty ? members.length : present.length) > shown.length)
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              '+${(present.isEmpty ? members.length : present.length) - shown.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentStepCard extends StatelessWidget {
  const _CurrentStepCard({
    required this.template,
    required this.current,
    required this.next,
    required this.index,
    required this.total,
  });

  final RoomTemplate template;
  final AgendaStep? current;
  final AgendaStep? next;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (current == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: GatherColors.muted),
        ),
        child: const Text(
          "The plan hasn't started yet.",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      );
    }

    final progress = total == 0 ? 0.0 : (index + 1) / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GatherColors.gold, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HAPPENING NOW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: GatherColors.goldDeep,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            current!.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: GatherColors.muted),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'Next: ${next!.title}',
                    style: const TextStyle(
                      color: GatherColors.muted,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Gap.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: GatherColors.muted.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(GatherColors.ultramarine),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Step ${index + 1} of $total',
            style: const TextStyle(color: GatherColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.state,
    required this.isOwner,
    required this.onToggleDone,
    this.onTap,
  });

  final AgendaStep step;
  final AgendaStepState state;
  final bool isOwner;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == AgendaStepState.current;
    final isDone = state == AgendaStepState.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: isCurrent ? GatherColors.gold.withValues(alpha: 0.14) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent ? GatherColors.goldDeep : GatherColors.muted,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggleDone,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDone
                          ? GatherColors.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isDone
                          ? null
                          : Border.all(color: GatherColors.muted, width: 2),
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isDone
                          ? GatherColors.muted
                          : GatherColors.ultramarineInk,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: GatherColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: GatherColors.ultramarineInk,
                      ),
                    ),
                  )
                else if (isOwner)
                  const Icon(Icons.chevron_right_rounded,
                      color: GatherColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GatherColors.muted),
      ),
      child: Text(
        message,
        style: const TextStyle(color: GatherColors.muted, height: 1.4),
      ),
    );
  }
}
