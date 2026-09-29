import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/room_snapshot.dart';
import '../theme.dart';

class PeopleTab extends StatelessWidget {
  const PeopleTab({super.key, required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final present = snapshot.members.where((m) => m.isCheckedIn).toList();
    final missing = snapshot.members.where((m) => !m.isCheckedIn).toList();
    final expected = snapshot.room.expectedCount;
    final stillToArrive = expected == null
        ? missing.length
        : (expected - present.length).clamp(0, expected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        Text(
          '${present.length} here'
          '${expected != null && expected > 0 ? ' · $stillToArrive to go' : ''}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GatherColors.muted,
          ),
        ),
        const SizedBox(height: Gap.md),
        if (present.isEmpty && missing.isEmpty)
          const _Note(
            'Nobody has joined yet. Share the room code to get people in.',
          ),
        for (final member in present) _MemberRow(member: member, checkedIn: true),
        if (present.isNotEmpty && missing.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.md),
            child: Divider(color: GatherColors.muted),
          ),
        for (final member in missing)
          _MemberRow(member: member, checkedIn: false),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.checkedIn});

  final Member member;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GatherColors.muted),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checkedIn
                    ? GatherColors.gold.withValues(alpha: 0.25)
                    : GatherColors.muted.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(member.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.isOwner
                        ? 'Organizer'
                        : checkedIn
                        ? 'Here since ${_time(member.checkedInAt)}'
                        : 'Joined, not checked in',
                    style: const TextStyle(
                      fontSize: 13,
                      color: GatherColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (checkedIn)
              const Icon(Icons.check_circle_rounded,
                  color: GatherColors.success, size: 22),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime? at) {
    if (at == null) return 'a moment ago';
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Note extends StatelessWidget {
  const _Note(this.message);

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
