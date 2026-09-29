import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/room_template.dart';
import '../theme.dart';

/// Emoji carries identity here instead of a photo or an account, which keeps
/// the guest flow to two taps.
const List<String> kEmojiChoices = [
  '😀', '🙌', '🔥', '🎉', '😎', '🤝', '🎧', '🍿',
  '⚡', '🌴', '🎬', '✊', '🚀', '🦄', '🍕', '🐢',
];

/// Shown on the landing screen and the join screen.
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final emoji in kEmojiChoices)
          _EmojiChip(
            emoji: emoji,
            isSelected: emoji == selected,
            onTap: () => onSelected(emoji),
          ),
      ],
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Choose $emoji',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? GatherColors.gold : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? GatherColors.goldDeep : GatherColors.muted,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

/// The three templates as tappable cards. Config only: picking a type sets
/// labels and toggles, it does not change the screen structure.
class RoomTypePicker extends StatelessWidget {
  const RoomTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RoomType? selected;
  final ValueChanged<RoomType> onSelected;

  static const _decor = {
    RoomType.meetup: ('🎤', 'Meetup'),
    RoomType.trip: ('🌴', 'Trip'),
    RoomType.movie: ('🎬', 'Movie night'),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in RoomType.values) ...[
          Expanded(
            child: _TypeCard(
              emoji: _decor[type]!.$1,
              label: _decor[type]!.$2,
              itemLabel: templateFor(type).itemLabel,
              isSelected: selected == type,
              onTap: () => onSelected(type),
            ),
          ),
          if (type != RoomType.values.last) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.emoji,
    required this.label,
    required this.itemLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String itemLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: '$label, posts $itemLabel',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            vertical: Gap.md,
            horizontal: Gap.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? GatherColors.ultramarine : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? GatherColors.ultramarine
                  : GatherColors.muted,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: Gap.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isSelected
                      ? Colors.white
                      : GatherColors.ultramarineInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                itemLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? GatherColors.offWhite
                      : GatherColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
