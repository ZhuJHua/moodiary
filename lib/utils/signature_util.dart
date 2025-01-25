import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

class SignatureUtil {
  static String _hex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int part in bytes) {
      buffer.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
    }
    return buffer.toString();
  }

  static String sha256HexToLowercase(String input) {
    return sha256.convert(utf8.encode(input)).toString().toLowerCase();
  }

  static List<int> hmacSha256(List<int> key, List<int> data) {
    return Hmac(sha256, key).convert(data).bytes;
  }

  //生成腾讯云签名
  static String generateSignature(String id, String key, int timestamp, body) {
    final String dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
            .toString()
            .split(' ')[0];
    //拼接规范请求串
    final canonicalRequest =
        'POST\n/\n\ncontent-type:application/json\nhost:hunyuan.tencentcloudapi.com\nx-tc-action:chatcompletions\n\ncontent-type;host;x-tc-action\n${sha256HexToLowercase(jsonEncode(body))}';
    //待签名字符串
    final stringToSign =
        'TC3-HMAC-SHA256\n${timestamp ~/ 1000}\n$dateTime/hunyuan/tc3_request\n${sha256HexToLowercase(canonicalRequest)}';
    final date = hmacSha256(utf8.encode('TC3$key'), utf8.encode(dateTime));
    final service = hmacSha256(date, utf8.encode('hunyuan'));
    final signing = hmacSha256(service, utf8.encode('tc3_request'));
    final signature = hmacSha256(signing, utf8.encode(stringToSign));
    final authorization =
        'TC3-HMAC-SHA256 Credential=$id/$dateTime/hunyuan/tc3_request, SignedHeaders=content-type;host;x-tc-action, Signature=${_hex(signature).toLowerCase()}';
    return authorization;
  }

  static Map<String, String>? checkTencent() {
    final id = PrefUtil.getValue<String>('tencentId');
    final key = PrefUtil.getValue<String>('tencentKey');
    if (id == null || key == null) {
      NoticeUtil.showToast('请先配置Key');
      return null;
    } else {
      return {'id': id, 'key': key};
    }
  }
}
