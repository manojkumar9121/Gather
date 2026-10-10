import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import '../state/room_controller.dart';
import '../theme.dart';
import '../widgets/end_event_button.dart';

/// The first tab. Someone opening the room should be able to answer "where are
/// we?" without scrolling, so the current step is the loudest thing here.
class NowTab extends StatelessWidget {
  const NowTab({super.key, required this.controller, required this.snapshot});

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final template = templateFor(snapshot.room.type);
    final current = snapshot.currentStep;
    final next = snapshot.nextStep;
    final isOwner = snapshot.viewer?.isOwner ?? false;
    final planComplete = snapshot.isPlanCompleted;
    final eventEnded = snapshot.isEventEnded;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        _CheckInCard(controller: controller, snapshot: snapshot),
        const SizedBox(height: Gap.lg),
        if (!planComplete) ...[
          Text(
            template.agendaLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: GatherColors.mutedText,
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
        ],
        // A finished plan shows one completion card and then the full agenda,
        // all ticked off, rather than replacing the list entirely.
        if (eventEnded)
          const _EventEndedCard()
        else if (planComplete)
          _PlanCompletedCard(controller: controller, canEndEvent: isOwner),
        if (planComplete || snapshot.steps.isEmpty)
          const SizedBox(height: Gap.lg),
        if (!planComplete && snapshot.steps.isEmpty)
          const _EmptyNote(
            message:
                'No plan yet. The organizer can add the steps everyone should '
                'expect.',
          ),
        for (final step in snapshot.steps)
          _StepRow(
            step: step,
            state: snapshot.stateFor(step),
            // Only the organizer moves the plan, and only forward.
            onTap:
                isOwner &&
                    !eventEnded &&
                    snapshot.stateFor(step) == AgendaStepState.upcoming
                ? () => controller.setCurrentStep(step.id)
                : null,
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
        color: GatherColors.blackSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x23FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: GatherColors.auroraGold,
                size: 22,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    color: GatherColors.whiteText,
                    fontSize: 18,
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
                backgroundColor: GatherColors.auroraGold,
                foregroundColor: const Color(0xFF221900),
              ),
              onPressed: () => controller.checkIn(),
              icon: const Icon(Icons.how_to_reg_rounded),
              label: Text(template.checkInLabel),
            ),
          ] else ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: GatherColors.success,
                  size: 20,
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  "You're checked in",
                  style: const TextStyle(
                    color: Color(0xCCF4F2FF),
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
        style: TextStyle(color: GatherColors.mutedText, fontSize: 14),
      );
    }

    final present = members.where((m) => m.isCheckedIn).toList();
    final pool = present.isEmpty ? members : present;
    final shown = pool.take(8).toList();

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
                  ? GatherColors.auroraGold.withValues(alpha: 0.35)
                  : const Color(0x2FFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(
                color: member.isCheckedIn
                    ? GatherColors.auroraGold.withValues(alpha: 0.6)
                    : const Color(0x1AFFFFFF),
              ),
            ),
            child: Text(member.emoji, style: const TextStyle(fontSize: 19)),
          ),
        if (pool.length > shown.length)
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x2FFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Text(
              '+${pool.length - shown.length}',
              style: const TextStyle(
                color: GatherColors.whiteText,
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
          color: GatherColors.blackSurface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Text(
          "The plan hasn't started yet.",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: GatherColors.mutedText,
          ),
        ),
      );
    }

    final progress = total == 0 ? 0.0 : (index + 1) / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GatherColors.blackSurface.withValues(alpha: 0.85),
            const Color(0x1A06051A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
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
                  color: GatherColors.auroraGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NOW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: GatherColors.auroraGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            current!.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: GatherColors.whiteText,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Icon(
                next == null ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                size: 16,
                color: next == null
                    ? GatherColors.auroraGold
                    : GatherColors.mutedText,
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  next == null ? 'Last step' : 'Next: ${next!.title}',
                  style: TextStyle(
                    color: next == null
                        ? GatherColors.auroraGold
                        : GatherColors.mutedText,
                    fontSize: 15,
                    fontWeight: next == null ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0x1FFFFFFF),
              valueColor: const AlwaysStoppedAnimation(GatherColors.auroraGold),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Step ${index + 1} of $total',
            style: const TextStyle(
              color: GatherColors.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step state is derived from the room's current pointer. There is no stored
/// flag to disagree with it, and nothing here can be ticked off by hand.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.state, this.onTap});

  final AgendaStep step;
  final AgendaStepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == AgendaStepState.current;
    final isDone = state == AgendaStepState.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              color: isCurrent
                  ? GatherColors.auroraGold.withValues(alpha: 0.1)
                  : isDone
                  ? null
                  : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent
                    ? GatherColors.auroraGold.withValues(alpha: 0.4)
                    : isDone
                    ? const Color(0x0AFFFFFF)
                    : const Color(0x1FFFFFFF),
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDone
                        ? GatherColors.success.withValues(alpha: 0.3)
                        : isCurrent
                        ? GatherColors.auroraGold.withValues(alpha: 0.35)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isDone || isCurrent
                        ? null
                        : Border.all(
                            color: GatherColors.mutedText.withValues(
                              alpha: 0.4,
                            ),
                            width: 2,
                          ),
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: GatherColors.success,
                        )
                      : isCurrent
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: GatherColors.auroraGold,
                        )
                      : null,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isDone
                          ? GatherColors.mutedText.withValues(alpha: 0.5)
                          : isCurrent
                          ? GatherColors.whiteText
                          : const Color(0xBBF4F2FF),
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
                else if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0x4DF4F2FF),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown once the organizer completes the plan. The organizer gets the one
/// terminal action here; everyone else just sees the finished state.
class _PlanCompletedCard extends StatelessWidget {
  const _PlanCompletedCard({
    required this.controller,
    required this.canEndEvent,
  });

  final RoomController controller;
  final bool canEndEvent;

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
            GatherColors.auroraGold.withValues(alpha: 0.15),
            GatherColors.blackSurface.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GatherColors.auroraGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(height: Gap.sm),
          const Text(
            'Plan complete — wrap up finished',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GatherColors.auroraGold,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'All steps are done. The group can now move on.',
            style: TextStyle(
              color: GatherColors.mutedText.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canEndEvent) ...[
            const SizedBox(height: Gap.lg),
            EndEventButton(controller: controller),
          ],
        ],
      ),
    );
  }
}

/// Terminal state. Deliberately calm: the event is over, not an error.
class _EventEndedCard extends StatelessWidget {
  const _EventEndedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: GatherColors.blackSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: GatherColors.success,
            size: 28,
          ),
          const SizedBox(height: Gap.sm),
          const Text(
            'Event ended',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: GatherColors.whiteText,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'That’s everything. This room is now read-only.',
            style: TextStyle(
              color: GatherColors.mutedText.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        color: GatherColors.blackSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: GatherColors.mutedText.withValues(alpha: 0.85),
          height: 1.4,
          fontSize: 14,
        ),
      ),
    );
  }
}
