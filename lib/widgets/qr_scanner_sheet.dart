import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/deep_links.dart';
import '../theme.dart';

/// Full-screen camera scanner used from the join screen.
///
/// A scan and a deep link are treated identically: both just supply a room
/// code, and both go through the same parser.
class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // The stream fires continuously, so guard against resolving twice.
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final code = codeFromQrPayload(barcode.rawValue);
      if (code == null) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _ScannerError(error: error.errorDetails?.message),
          ),
          const _ScannerOverlay(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Close scanner',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(Gap.lg),
                child: Text(
                  'Point the camera at the room QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: GatherColors.gold, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                color: Colors.white70,
                size: 44,
              ),
              const SizedBox(height: Gap.md),
              const Text(
                'We could not use the camera.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                error ?? 'Type the 5 character code instead.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
