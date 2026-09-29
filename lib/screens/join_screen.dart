import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/local_room_repository.dart';
import '../domain/room_event.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import 'create_room_screen.dart';
import 'room_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _codeController = TextEditingController(
    text: widget.initialCode,
  );
  final _nameController = TextEditingController();

  String _emoji = kEmojiChoices.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = LocalRoomRepository.normaliseCode(_codeController.text);
    if (code.length != 5) {
      setState(() => _error = 'A room code is 5 characters.');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Add a name so people know who you are.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repository = RepositoryScope.of(context);
    try {
      final snapshot = await repository.joinRoom(
        code: code,
        displayName: _nameController.text,
        emoji: _emoji,
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
    } on GatherRuleException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong joining that room. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          children: [
            const Text(
              'Room code',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _codeController,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(5),
                TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(
                    text: next.text.toUpperCase(),
                  ),
                ),
              ],
              decoration: const InputDecoration(hintText: 'K7QP2'),
            ),
            const SizedBox(height: Gap.lg),
            const Text(
              'Your name',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Sam'),
            ),
            const SizedBox(height: Gap.lg),
            const Text(
              'Pick an emoji',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: Gap.sm),
            EmojiPicker(
              selected: _emoji,
              onSelected: (emoji) => setState(() => _emoji = emoji),
            ),
            const SizedBox(height: Gap.sm),
            const Text(
              'No account needed. Your name and emoji are only visible inside '
              'this room.',
              style: TextStyle(color: GatherColors.muted, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.lg),
              ErrorNote(message: _error!),
            ],
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Join room'),
            ),
          ],
        ),
      ),
    );
  }
}
