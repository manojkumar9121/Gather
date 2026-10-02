import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/local_room_repository.dart';
import 'package:gather/domain/models.dart';

/// The join QR, the deep link and the in-app scanner all have to agree on what
/// a code is, and the room has to accept what they produce. These lock that
/// contract down from both ends.
void main() {
  late LocalRoomRepository repo;

  setUp(() => repo = LocalRoomRepository());
  tearDown(() => repo.dispose());

  test('a room code round-trips through normaliseCode', () async {
    final room = await repo.createRoom(
      title: 'Test',
      type: RoomType.meetup,
      ownerName: 'Alex',
      ownerEmoji: '🙌',
    );
    final code = room.room.code;

    // What a scanner or a hand-typed field can hand over.
    final typed = LocalRoomRepository.normaliseCode('  ${code.toLowerCase()} ');
    expect(typed, code);
    expect(LocalRoomRepository.normaliseCode('k7 qp2'), 'K7QP2');
    expect(LocalRoomRepository.normaliseCode('k7-qp_2'), 'K7QP2');
  });

  test('a joined guest can check in after scanning a meetup QR', () async {
    final room = await repo.createRoom(
      title: 'Test',
      type: RoomType.meetup,
      ownerName: 'Alex',
      ownerEmoji: '🙌',
    );

    final guest = await repo.joinRoom(
      code: room.room.code,
      displayName: 'Sam',
      emoji: '🔥',
      guestId: 'device-1',
      viaQr: true,
    );

    expect(guest.viewer!.isCheckedIn, isTrue);
    expect(guest.checkedInCount, 1);
  });
}
