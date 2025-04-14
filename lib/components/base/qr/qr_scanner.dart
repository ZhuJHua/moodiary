import 'dart:async';
import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/router/app_pages.dart';
import 'package:moodiary/utils/aes_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:throttling/throttling.dart';

Future<String?> showQrScanner({
  required BuildContext context,
  Duration? validDuration,
  String? prefix,
}) async {
  return Navigator.push<String?>(
    context,
    MoodiaryFadeInPageRoute(
      builder: (context) {
        return QrScanner(validDuration: validDuration, prefix: prefix);
      },
    ),
  );
}

class QrScanner extends StatefulWidget {
  final Duration? validDuration;

  final String? prefix;

  const QrScanner({super.key, this.validDuration, this.prefix});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: Durations.long4,
  )..repeat(reverse: true);

  late final Animation<double> _curvedAnimation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeInOut,
  );

  late final MobileScannerController _scannerController =
      MobileScannerController(
        invertImage: true,
        autoStart: false,
        cameraResolution: const Size.square(640),
        formats: [BarcodeFormat.qrCode],
      );

  late final Throttling _throttling = Throttling();

  late final AppLifecycleListener _appLifecycleListener;

  StreamSubscription<Object?>? _subscription;

  late final ValueNotifier<TorchState> _torchState = ValueNotifier(
    TorchState.unavailable,
  );

  @override
  void initState() {
    _subscription = _scannerController.barcodes.listen(_handleBarcode);

    _appLifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (!_scannerController.value.hasCameraPermission) {
          return;
        }
        switch (state) {
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            return;
          case AppLifecycleState.resumed:
            _subscription = _scannerController.barcodes.listen(_handleBarcode);
            unawaited(_scannerController.start());
          case AppLifecycleState.inactive:
            unawaited(_subscription?.cancel());
            _subscription = null;
            unawaited(_scannerController.stop());
        }
      },
    );
    _scannerController.addListener(() {
      if (_scannerController.value.torchState != _torchState.value) {
        _torchState.value = _scannerController.value.torchState;
      }
    });
    unawaited(_scannerController.start());
    super.initState();
  }

  @override
  void dispose() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _animationController.dispose();
    _throttling.close();
    _appLifecycleListener.dispose();
    super.dispose();
    await _scannerController.dispose();
  }

  void _handleBarcode(BarcodeCapture value) {
    _throttling.throttle(() async {
      final raw = value.barcodes.firstOrNull?.rawValue;
      if (raw == null) return;

      try {
        if (widget.validDuration != null) {
          final resBytes = base64Decode(raw);
          final decrypted = await AesUtil.decryptWithTimeWindow(
            encryptedData: resBytes,
            validDuration: widget.validDuration!,
          );
          if (decrypted.isNullOrBlank) {
            _handleInvalidQr();
            return;
          }
          if (widget.prefix.isNotNullOrBlank) {
            if (!decrypted!.startsWith(widget.prefix!)) {
              _handleInvalidQr();
              return;
            }
            final realData = decrypted.substring(widget.prefix!.length);
            if (mounted) Navigator.pop(context, realData);
          } else {
            if (mounted) Navigator.pop(context, decrypted);
          }
        } else {
          if (raw.isNullOrBlank) {
            _handleInvalidQr();
          } else {
            if (mounted) Navigator.pop(context, raw);
          }
        }
      } catch (e) {
        logger.d(e);
        _handleInvalidQr();
      }
    });
  }

  void _handleInvalidQr() {
    if (mounted) {
      toast.info(message: context.l10n.qrCodeInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(Offset.zero),
      width: 200,
      height: 200,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            scanWindow: scanWindow,
            controller: _scannerController,
            overlayBuilder: (context, constraints) {
              return AnimatedBuilder(
                animation: _curvedAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      CustomPaint(
                        size: constraints.biggest,
                        painter: _ScannerOverlayPainter(
                          centerSize: _curvedAnimation.value * 20 + 200,
                        ),
                      ),
                      Center(
                        child: CustomPaint(
                          size: Size.square(_curvedAnimation.value * 20 + 200),
                          painter: _CornerBorderPainter(
                            color: Colors.white,
                            strokeWidth: 4,
                            cornerLength: _curvedAnimation.value * 2 + 20,
                            radius: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Positioned(
            bottom: MediaQuery.sizeOf(context).height / 2 - 300,
            child: ValueListenableBuilder(
              valueListenable: _torchState,
              builder: (context, value, child) {
                if (value == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                  },
                  iconSize: 56,
                  icon: switch (_torchState.value) {
                    TorchState.auto => const Icon(
                      Icons.flash_auto_rounded,
                      color: Colors.white,
                    ),
                    TorchState.off => const Icon(
                      Icons.flashlight_off_rounded,
                      color: Colors.white54,
                    ),
                    TorchState.on => const Icon(
                      Icons.flashlight_on_rounded,
                      color: Colors.white,
                    ),
                    TorchState.unavailable => throw UnimplementedError(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  _CornerBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.cornerLength = 20,
    this.radius = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = Path();

    final double w = size.width;
    final double h = size.height;
    final r = radius;

    path.moveTo(0, r + cornerLength);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.lineTo(r + cornerLength, 0);

    path.moveTo(w - r - cornerLength, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, r + cornerLength);

    path.moveTo(w, h - r - cornerLength);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(w - r - cornerLength, h);

    path.moveTo(r + cornerLength, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, h - r - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerOverlayPainter extends CustomPainter {
  final double centerSize;

  _ScannerOverlayPainter({required this.centerSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.fill;

    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final scanSize = centerSize;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    final hole = Path()..addRRect(RRect.fromRectXY(scanRect, 12, 12));
    final overlay = Path.combine(PathOperation.difference, outer, hole);

    canvas.drawPath(overlay, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
