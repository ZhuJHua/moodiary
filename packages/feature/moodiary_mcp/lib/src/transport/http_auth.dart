import 'dart:convert';
import 'dart:io';

/// `Bearer` plus one token, tolerating extra spaces and any letter case of the
/// scheme (HTTP auth schemes are case insensitive).
final RegExp _bearerPattern = RegExp(r'^Bearer +(\S+)$', caseSensitive: false);

/// Compares two strings without returning early on the first mismatch.
///
/// The lengths still leak, the contents do not; that is the usual trade-off for
/// a shared secret of fixed length.
bool constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  var difference = aBytes.length ^ bBytes.length;
  final length = aBytes.length > bBytes.length ? aBytes.length : bBytes.length;
  for (var i = 0; i < length; i++) {
    final aByte = i < aBytes.length ? aBytes[i] : 0;
    final bByte = i < bBytes.length ? bBytes[i] : 0;
    difference |= aByte ^ bByte;
  }
  return difference == 0;
}

/// `true` when [request] carries exactly one `Authorization: Bearer <expected>`
/// header. An empty [expected] token rejects everything: a transport that was
/// given no secret must stay closed.
bool hasValidBearerToken(HttpRequest request, String expected) {
  if (expected.isEmpty) return false;
  final values = request.headers[HttpHeaders.authorizationHeader];
  if (values == null || values.length != 1) return false;
  final match = _bearerPattern.firstMatch(values.single.trim());
  if (match == null) return false;
  final presented = match.group(1)!;
  return constantTimeEquals(presented, expected);
}
