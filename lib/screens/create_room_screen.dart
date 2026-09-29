import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../domain/models.dart';
import '../domain/room_template.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import 'room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _titleController = TextEditingController();
  final _nameController = TextEditingController();
  final _expectedController = TextEditingController();

  RoomType? _type;
  String _emoji = kEmojiChoices.first;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expectedController.text = '${kDefaultExpected[RoomType.meetup] ?? 20}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _expectedController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final type = _type;
    if (type == null) {
      setState(() => _error = 'Pick what kind of room this is.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Give the room a name so people know what it is.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repository = RepositoryScope.of(context);
    final expected = int.tryParse(_expectedController.text.trim());

    try {
      final snapshot = await repository.createRoom(
        title: _titleController.text,
        type: type,
        ownerName: _nameController.text,
        ownerEmoji: _emoji,
        expectedCount: expected,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RoomScreen(
            code: snapshot.room.code,
            viewerMemberId: snapshot.viewerMemberId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          children: [
            _Label('What kind of room?'),
            RoomTypePicker(
              selected: _type,
              onSelected: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: Gap.lg),
            _Label('Room name'),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _type == null
                    ? 'Friday film club'
                    : 'Film club, Friday 8pm',
              ),
            ),
            const SizedBox(height: Gap.lg),
            _Label('How many people, roughly?'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expectedController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: '20'),
                  ),
                ),
                const SizedBox(width: Gap.md),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Used for the "12 of 20 here" counter.',
                    style: TextStyle(
                      color: GatherColors.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            _Label('Your name'),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Alex'),
            ),
            const SizedBox(height: Gap.md),
            _Label('Pick an emoji'),
            EmojiPicker(
              selected: _emoji,
              onSelected: (emoji) => setState(() => _emoji = emoji),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.lg),
              _ErrorNote(_error!),
            ],
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create room'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: GatherColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GatherColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: GatherColors.danger, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: GatherColors.danger, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reused by the join screen.
class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      _ErrorNote(message);
}
