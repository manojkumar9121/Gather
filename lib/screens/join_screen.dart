import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/guest_identity.dart';
import '../data/local_room_repository.dart';
import '../domain/room_event.dart';
import '../theme.dart';
import '../widgets/pickers.dart';
import '../widgets/qr_scanner_sheet.dart';
import 'create_room_screen.dart';
import 'room_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({
    super.key,
    this.initialCode,
    this.identity,
    this.identityStore,
  });

  final String? initialCode;

  /// Passed in when the screen is pushed from a deep link, so the guest does
  /// not have to retype the name and emoji they already chose.
  final GuestIdentity? identity;
  final GuestIdentityStore? identityStore;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _codeController = TextEditingController(
    text: widget.initialCode,
  );
  late final TextEditingController _nameController = TextEditingController(
    text: widget.identity?.displayName,
  );

  late String _emoji = widget.identity?.emoji ?? kEmojiChoices.first;
  bool _busy = false;
  String? _error;

  GuestIdentityStore? get _store => widget.identityStore;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerSheet()),
    );
    if (code == null || !mounted) return;
    setState(() {
      _codeController.text = code;
      _error = null;
    });
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
    // Fall back to the app-level store when this screen was pushed from a
    // deep link and no store was threaded through. Read the scope and the
    // navigator before the awaits, so no context is used across the gap.
    final scope = IdentityScope.of(context);
    final store = _store ?? scope.store;
    final identity = widget.identity ?? scope.identity;
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();

    try {
      final snapshot = await repository.joinRoom(
        code: code,
        displayName: _nameController.text,
        emoji: _emoji,
        // The same device id means a returning phone gets its old member back
        // rather than inflating the check-in count.
        guestId: identity?.guestId,
        // Scanning the QR in a meetup room is arriving, per the template.
        viaQr: widget.initialCode != null,
      );
      // Not awaited: a disk write should never hold up the transition.
      unawaited(store.saveName(name, _emoji));
      unawaited(store.saveLastRoom(code));

      if (!mounted) return;
      await navigator.pushReplacement(
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
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                        (_, next) =>
                            next.copyWith(text: next.text.toUpperCase()),
                      ),
                    ],
                    decoration: const InputDecoration(hintText: 'K7QP2'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                SizedBox(
                  width: kTapTarget,
                  height: kTapTarget,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _scan,
                    child: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ],
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
