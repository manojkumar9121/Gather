import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/room_snapshot.dart';
import '../domain/room_template.dart';
import '../state/room_controller.dart';
import '../theme.dart';

class ItemsTab extends StatefulWidget {
  const ItemsTab({
    super.key,
    required this.controller,
    required this.snapshot,
  });

  final RoomController controller;
  final RoomSnapshot snapshot;

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    await widget.controller.addItem(text);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final room = snapshot.room;
    final template = templateFor(room.type);
    // Items arrive in the order the server wants them. Re-sorting here is how
    // a list ends up reshuffling under someone's thumb.
    final items = snapshot.items;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
            children: [
              if (room.isClosed) ...[
                _ResultCard(snapshot: snapshot),
                const SizedBox(height: Gap.lg),
              ],
              if (items.isEmpty)
                _EmptyItems(template: template, room: room)
              else
                for (final view in items)
                  _ItemRow(
                    view: view,
                    snapshot: snapshot,
                    onVote: room.isVoting
                        ? () => widget.controller.toggleVote(view.item.id)
                        : null,
                  ),
            ],
          ),
        ),
        if (!room.isClosed)
          _Composer(
            controller: _controller,
            focus: _focus,
            template: template,
            onSubmit: _submit,
          ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final winner = snapshot.winner;

    // Nobody voted. This is a designed state rather than a fallback: a plain
    // dot instead of the gold accent, no confetti, one plain line. A grey
    // result reads as "nothing happened" and not as "something broke".
    if (winner == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: kStageBackground,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            Icon(Icons.circle, size: 10, color: GatherColors.muted),
            SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'Nobody voted this time. Start another?',
                style: TextStyle(
                  color: GatherColors.offWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: kStageBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'WINNER',
                style: TextStyle(
                  color: GatherColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              if (snapshot.room.wasTie) ...[
                const SizedBox(width: Gap.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: GatherColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TIE, BROKEN AT RANDOM',
                    style: TextStyle(
                      color: GatherColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            winner.item.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            winner.votes == 1 ? '1 vote' : '${winner.votes} votes',
            style: const TextStyle(color: GatherColors.muted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.view,
    required this.snapshot,
    this.onVote,
  });

  final ItemView view;
  final RoomSnapshot snapshot;
  final VoidCallback? onVote;

  @override
  Widget build(BuildContext context) {
    final item = view.item;
    final author = snapshot.memberById(item.authorMemberId);

    // Guests never see who wrote an anonymous item. The organizer keeps
    // visibility so they can moderate.
    final byline = view.authorHidden
        ? 'Anonymous'
        : '${author?.emoji ?? '🙂'} ${author?.displayName ?? 'Someone'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
        decoration: BoxDecoration(
          color: view.votedByMe
              ? GatherColors.gold.withValues(alpha: 0.16)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: view.votedByMe ? GatherColors.goldDeep : GatherColors.muted,
            width: view.votedByMe ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      byline,
                      style: const TextStyle(
                        fontSize: 13,
                        color: GatherColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            _VoteButton(view: view, onTap: onVote),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.view, this.onTap});

  final ItemView view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isVoted = view.votedByMe;

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: isVoted,
      label: isVoted
          ? 'Remove your vote, ${view.votes} votes'
          : 'Vote for this, ${view.votes} votes',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 64, minHeight: kTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isVoted ? GatherColors.ultramarine : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVoted ? GatherColors.ultramarine : GatherColors.muted,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVoted
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isVoted ? GatherColors.gold : GatherColors.ultramarine,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                '${view.votes}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isVoted ? Colors.white : GatherColors.ultramarine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.template,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final RoomTemplate template;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.md,
        Gap.lg,
        Gap.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: GatherColors.muted)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '${template.itemVerb} something…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
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
              onPressed: onSubmit,
              child: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({required this.template, required this.room});

  final RoomTemplate template;
  final Room room;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GatherColors.muted),
      ),
      child: Column(
        children: [
          const Text('💡', style: TextStyle(fontSize: 40)),
          const SizedBox(height: Gap.md),
          Text(
            room.isVoting
                ? 'No ${template.itemLabel.toLowerCase()} yet. Voting just '
                      'started, so be quick.'
                : 'No ${template.itemLabel.toLowerCase()} yet. Be the first to '
                      'add one below.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: GatherColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
