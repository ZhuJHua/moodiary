import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/aes_util.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EncryptQrCode extends StatefulWidget {
  final String data;
  final double size;
  final Duration validDuration;
  final String? prefix;

  const EncryptQrCode({
    super.key,
    required this.data,
    this.size = 64,
    this.validDuration = const Duration(minutes: 2),
    this.prefix,
  });

  @override
  State<EncryptQrCode> createState() => _EncryptQrCodeState();
}

class _EncryptQrCodeState extends State<EncryptQrCode> {
  Uint8List? encryptedData;
  late int expireAt; // Unix 时间戳
  bool isExpired = false;

  @override
  void initState() {
    super.initState();
    _encryptData();
  }

  Future<void> _encryptData() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expireAt = now + widget.validDuration.inSeconds;

    final aesData = await AesUtil.encryptWithTimeWindow(
      data: '${widget.prefix}${widget.data}',
      validDuration: widget.validDuration,
    );

    setState(() {
      isExpired = false;
      encryptedData = aesData;
    });

    _startExpirationChecker();
  }

  void _startExpirationChecker() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= expireAt) {
        setState(() {
          isExpired = true;
        });
        timer.cancel();
      }
    });
  }

  Widget _buildQrChild() {
    if (encryptedData == null) {
      return Center(
        key: const ValueKey('loading'),
        child: CircularProgressIndicator(
          color: context.theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (isExpired) {
      return GestureDetector(
        key: const ValueKey('expired'),
        onTap: _encryptData,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_rounded,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                '已过期',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return QrImageView(
      key: const ValueKey('qr'),
      data: base64Encode(encryptedData!),
      size: widget.size,
      backgroundColor: Colors.transparent,
      dataModuleStyle: QrDataModuleStyle(
        color: context.theme.colorScheme.onSurface,
        dataModuleShape: QrDataModuleShape.circle,
      ),
      eyeStyle: QrEyeStyle(
        color: context.theme.colorScheme.onSurface,
        eyeShape: QrEyeShape.circle,
      ),
      gapless: false,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedSwitcher(
        duration: Durations.medium2,
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _buildQrChild(),
      ),
    );
  }
}
