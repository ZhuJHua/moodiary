import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mood_diary/utils/utils.dart';

class SignatureUtil {
  String hex(List<int> bytes) {
    StringBuffer buffer = StringBuffer();
    for (int part in bytes) {
      buffer.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
    }
    return buffer.toString();
  }

  String sha256HexToLowercase(String input) {
    return sha256.convert(utf8.encode(input)).toString().toLowerCase();
  }

  List<int> hmacSha256(List<int> key, List<int> data) {
    return Hmac(sha256, key).convert(data).bytes;
  }

  //生成腾讯云签名
  String generateSignature(String id, String key, int timestamp, body) {
    String dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toString().split(' ')[0];
    //拼接规范请求串
    var canonicalRequest =
        'POST\n/\n\ncontent-type:application/json\nhost:hunyuan.tencentcloudapi.com\nx-tc-action:chatcompletions\n\ncontent-type;host;x-tc-action\n${sha256HexToLowercase(jsonEncode(body))}';
    //待签名字符串
    var stringToSign =
        'TC3-HMAC-SHA256\n${timestamp ~/ 1000}\n$dateTime/hunyuan/tc3_request\n${sha256HexToLowercase(canonicalRequest)}';
    var date = hmacSha256(utf8.encode('TC3$key'), utf8.encode(dateTime));
    var service = hmacSha256(date, utf8.encode('hunyuan'));
    var signing = hmacSha256(service, utf8.encode('tc3_request'));
    var signature = hmacSha256(signing, utf8.encode(stringToSign));
    var authorization =
        'TC3-HMAC-SHA256 Credential=$id/$dateTime/hunyuan/tc3_request, SignedHeaders=content-type;host;x-tc-action, Signature=${hex(signature).toLowerCase()}';
    return authorization;
  }

  Map<String, String>? checkTencent() {
    var id = Utils().prefUtil.getValue<String>('tencentId');
    var key = Utils().prefUtil.getValue<String>('tencentKey');
    if (id == null || key == null) {
      Utils().noticeUtil.showToast('请先配置Key');
      return null;
    } else {
      return {'id': id, 'key': key};
    }
  }
}
