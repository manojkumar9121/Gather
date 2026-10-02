import 'package:flutter_test/flutter_test.dart';
import 'package:gather/data/deep_links.dart';
import 'package:qr/qr.dart';

void main() {
  test('the link the QR encodes is encodable and parses back to the code', () {
    // Exactly what _CodeCard in the organizer panel puts in the QR.
    const code = 'NJUZ7';
    final link = joinLink(code);
    expect(link, 'gather://join/$code');

    // The QR has to be generatable at all. A link the encoder rejects would
    // leave the organizer holding a code nobody can scan.
    final encoded = QrCode.fromData(
      data: link,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    expect(encoded.typeNumber, greaterThanOrEqualTo(1));

    // The encoder writes exactly [link], the camera hands back exactly
    // [link], so the parser has to recover the code from that string. The
    // `qr` package dropped its decoder in 3.x, so the round trip is closed on
    // our side of the contract: writer and reader are the same functions the
    // scanner and the deep-link handler call.
    expect(codeFromQrPayload(link), code);
  });

  test('a scanned payload can be a bare code, a link, or junk', () {
    expect(codeFromQrPayload('NJUZ7'), 'NJUZ7');
    expect(codeFromQrPayload(' njuz7 '), 'NJUZ7');
    expect(codeFromQrPayload('gather://join/NJUZ7'), 'NJUZ7');
    expect(codeFromQrPayload('https://example.com/join/NJUZ7'), isNull);
    expect(codeFromQrPayload('not a code'), isNull);
    expect(codeFromQrPayload(null), isNull);
  });
}
