import 'package:flutter/material.dart';

import '../data/guest_identity.dart';
import '../theme.dart';
import 'create_room_screen.dart';
import 'join_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, this.identity});

  final GuestIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final lastRoom = identity?.lastRoomCode;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Wordmark(),
              const SizedBox(height: Gap.xl),
              Text(
                'Where your group decides.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'WhatsApp is where you talk. Gather is where you decide.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: GatherColors.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.xl),
              // Someone who already used the app should not have to remember
              // a five character code to get back where they were.
              if (lastRoom != null && lastRoom.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => JoinScreen(
                        initialCode: lastRoom,
                        identity: identity,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: Text('Back into room $lastRoom'),
                ),
                const SizedBox(height: Gap.sm),
              ],
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateRoomScreen(),
                  ),
                ),
                child: const Text('Create a room'),
              ),
              const SizedBox(height: Gap.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
                ),
                child: const Text('Join a room'),
              ),
              const SizedBox(height: Gap.xl),
              const _HowItWorks(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: GatherColors.ultramarine,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: GatherColors.gold,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        const Text(
          'gather',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: GatherColors.ultramarine,
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    ('1', 'One joins', 'Enter a code. No account, no signup.'),
    ('2', 'Everyone sees', 'Live counts and where the plan is now.'),
    ('3', 'It closes', 'A timed vote picks a winner. Done.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in _steps)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: GatherColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    step.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GatherColors.ultramarineInk,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.$3,
                        style: const TextStyle(
                          color: GatherColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
