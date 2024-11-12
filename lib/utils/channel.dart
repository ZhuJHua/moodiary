import 'package:flutter/services.dart';

class FontChannel {
  static const MethodChannel _channel = MethodChannel('font_channel');

  static Future<Object?> getFont() async {
    return await _channel.invokeMethod('getFont');
  }
}

class OAIDChannel {
  static const MethodChannel _channel = MethodChannel('oaid_channel');

  static Future<String?> getOAID() async {
    return await _channel.invokeMethod('getOAID');
  }
}
