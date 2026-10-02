import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/deep_links.dart';

void main() {
  group('QR payload and deep link parsing', () {
    test('reads the canonical gather://join/CODE link', () {
      expect(codeFromQrPayload('gather://join/HPC55'), 'HPC55');
      expect(codeFromQrPayload('gather://join/hpc55'), 'HPC55');
    });

    test('tolerates a bare five character code', () {
      // Someone types a code straight into a QR generator.
      expect(codeFromQrPayload('K7QP2'), 'K7QP2');
      expect(codeFromQrPayload('  k7qp2  '), 'K7QP2');
    });

    test('tolerates the gather://CODE shorthand', () {
      expect(codeFromQrPayload('gather://HPC55'), 'HPC55');
    });

    test('rejects anything that is not a room code', () {
      expect(codeFromQrPayload(null), isNull);
      expect(codeFromQrPayload(''), isNull);
      expect(codeFromQrPayload('gather://join/TOOLONG'), isNull);
      expect(codeFromQrPayload('gather://join/AB1'), isNull);
      expect(codeFromQrPayload('https://example.com/K7QP2'), isNull);
      expect(codeFromQrPayload('some other qr text'), isNull);
    });

    test('a generated link round-trips back to the same code', () {
      // This is the contract the organizer panel and the scanner depend on:
      // what the QR shows and what the scanner reads are the same string.
      for (final code in ['HPC55', 'K7QP2', 'ZZZZZ', 'ABCDE']) {
        final link = 'gather://join/$code';
        expect(codeFromQrPayload(link), code);
      }
    });
  });
}
