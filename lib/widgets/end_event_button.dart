import 'package:flutter/material.dart';

import '../state/room_controller.dart';
import '../theme.dart';

/// The terminal action for a room whose plan has run to the end. Ending an
/// event closes the room for everyone, so it sits behind a confirmation rather
/// than a single tap.
class EndEventButton extends StatelessWidget {
  const EndEventButton({super.key, required this.controller});

  final RoomController controller;

  Future<void> _confirmAndEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GatherColors.blackSurface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'End the event?',
          style: TextStyle(
            color: GatherColors.whiteText,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'The room closes for everyone. People can still look back at the '
          'plan, but nothing new can be added.',
          style: TextStyle(color: GatherColors.mutedText, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: GatherColors.whiteText,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GatherColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End the event'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.endEvent();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: GatherColors.whiteText,
        side: const BorderSide(color: Color(0x33FFFFFF), width: 1.5),
        backgroundColor: const Color(0x18FFFFFF),
      ),
      onPressed: () => _confirmAndEnd(context),
      icon: const Icon(Icons.stop_circle_outlined),
      label: const Text('End the event'),
    );
  }
}
