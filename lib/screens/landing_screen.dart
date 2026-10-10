import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import 'create_room_screen.dart';
import 'join_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Read through the scope rather than taking the identity as a constructor
    // argument. `MaterialApp.home` becomes a Navigator route once, so a new
    // `home:` widget on rebuild does not refresh the route already on screen --
    // which is why saving a room used to leave this page stale. An inherited
    // widget does reach the live route.
    final identity = IdentityScope.of(context).identity;
    final lastRoom = identity?.lastRoomCode;

    return Scaffold(
      body: Container(
        // Aurora Glass background: near-black with purple/blue aurora bloom
        decoration: const BoxDecoration(
          color: GatherColors.blackBase,
          gradient: RadialGradient(
            center: Alignment(-0.15, -0.25),
            radius: 1.4,
            colors: [
              Color(0x887040FF), // purple aurora bloom
              Color(0x00000000),
            ],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Large orb logo with glow for Aurora Glass
                const _AuroraOrbLogo(),
                const SizedBox(height: Gap.xl),
                // Gradient wordmark — "Gather"
                const Center(
                  child: Text(
                    'Gather',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.8,
                      height: 1.0,
                      color: GatherColors.auroraGold,
                      shadows: [
                        Shadow(
                          color: Color(0x66FFC83D),
                          blurRadius: 28,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                // Tagline
                Center(
                  child: Text(
                    'Where your group decides.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: GatherColors.mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Center(
                  child: Text(
                    'WhatsApp is where you talk. Gather is where you decide.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: GatherColors.mutedText.withValues(alpha: 0.55),
                      fontSize: 13.5,
                      height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                // Back to last room
                if (lastRoom != null && lastRoom.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JoinScreen(
                            initialCode: lastRoom,
                            identity: identity,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 20),
                      label: Text('Back into room $lastRoom'),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                ],
                // Primary button — gradient gold glow
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateRoomScreen(),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: GatherColors.auroraGold,
                    foregroundColor: GatherColors.blackBase,
                    elevation: 6,
                    shadowColor: GatherColors.auroraGold.withValues(
                      alpha: 0.55,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Create a room',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0x33FFFFFF),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Join a room',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: GatherColors.whiteText,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                const _HowItWorks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large glowing orb logo for Aurora Glass landing — uses actual app logo.
class _AuroraOrbLogo extends StatelessWidget {
  const _AuroraOrbLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Glowing orb background with aurora purple/blue bloom
        Stack(
          alignment: Alignment.center,
          children: [
            // Purple bloom on left
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, 0.2),
                  radius: 1.0,
                  colors: [
                    Color(0xB08040FF),
                    Color(0x2040A0FF),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
            // Blue bloom on right
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(0.7, -0.2),
                  radius: 1.0,
                  colors: [
                    Color(0xB03A2FE0),
                    Color(0x203A5AFF),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
            // Actual app logo image with gold glow
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xAAFFC83D),
                    blurRadius: 36,
                    spreadRadius: 8,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Color(0x55FFC83D),
                    blurRadius: 60,
                    spreadRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: ClipOval(
                child: Image.asset(
                  'gather-logo-1024.png',
                  width: 86,
                  height: 86,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
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
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: GatherColors.blackSurface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x22FFFFFF), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: GatherColors.auroraGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66FFC83D),
                          blurRadius: 14,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: GatherColors.blackBase,
                        fontSize: 15,
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
                            color: GatherColors.whiteText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.$3,
                          style: const TextStyle(
                            color: Color(0xFFB5AFD1),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
