import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'qr_crypto.dart';

/// 加密二维码组件。[prefix] 会在加密前拼到 [data] 前，供扫码端识别用途、避免误扫到别处的二维码。
class EncryptQrCode extends StatefulWidget {
  final String data;
  final double size;
  final Duration validDuration;
  final String? prefix;

  const EncryptQrCode({
    super.key,
    required this.data,
    this.size = 160,
    this.validDuration = const Duration(minutes: 2),
    this.prefix,
  });

  @override
  State<EncryptQrCode> createState() => _EncryptQrCodeState();
}

class _EncryptQrCodeState extends State<EncryptQrCode> {
  Uint8List? _encrypted;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _encrypt();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _encrypt() async {
    _timer?.cancel();
    if (mounted) setState(() => _expired = false);
    final payload = '${widget.prefix ?? ''}${widget.data}';
    final cipher = await QrCrypto.encryptWithTimeWindow(
      data: payload,
      validDuration: widget.validDuration,
    );
    if (!mounted) return;
    setState(() => _encrypted = cipher);
    _timer = Timer(widget.validDuration, () {
      if (mounted) setState(() => _expired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedSwitcher(
        duration: Durations.medium2,
        child: _buildBody(scheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_encrypted == null) {
      return Center(
        key: const ValueKey('loading'),
        child: CircularProgressIndicator(color: scheme.onSurfaceVariant),
      );
    }
    if (_expired) {
      return GestureDetector(
        key: const ValueKey('expired'),
        onTap: _encrypt,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                '已过期，点击重新生成',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return QrImageView(
      key: const ValueKey('qr'),
      data: base64Encode(_encrypted!),
      size: widget.size,
      backgroundColor: Colors.transparent,
      dataModuleStyle: QrDataModuleStyle(
        color: scheme.onSurface,
        dataModuleShape: QrDataModuleShape.circle,
      ),
      eyeStyle: QrEyeStyle(
        color: scheme.onSurface,
        eyeShape: QrEyeShape.circle,
      ),
      gapless: false,
      padding: EdgeInsets.zero,
    );
  }
}
