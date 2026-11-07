/// Authentication and browser origin policy of the local MCP endpoint.
///
/// The endpoint serves private diary data on a loopback (or LAN) socket, so
/// both checks are treated as hostile input code: the bearer token is compared
/// without early exit and the `Origin` header is only accepted for pages that
/// are served from this machine or from the very authority the request
/// addressed.
///
/// Package internal: not part of the package barrel.
library;

import 'dart:convert';
import 'dart:io';

/// Pages served from these hosts are browser local pages talking to the local
/// server; a random website can never have one of them as its origin.
const Set<String> _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

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
  final presented = match.group(1);
  if (presented == null) return false;
  return constantTimeEquals(presented, expected);
}

/// `true` when a page with this [origin] may call the endpoint.
///
/// Allowed are the loopback origins (`http(s)://localhost`, `127.0.0.1`,
/// `[::1]`, any port) and an origin whose authority is exactly the [host] the
/// request was addressed to, which is what a page served by this very endpoint
/// would send. Anything else, including a DNS name that resolves to loopback,
/// is a rebinding attempt.
bool isAllowedOrigin(String origin, {required String? host}) {
  if (origin.isEmpty || origin == 'null') return false;
  final parsed = Uri.tryParse(origin);
  if (parsed == null) return false;
  final scheme = parsed.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  final name = parsed.host.toLowerCase();
  if (name.isEmpty) return false;
  if (_loopbackHosts.contains(name)) return true;
  if (host == null) return false;
  final target = host.trim().toLowerCase();
  if (target.isEmpty) return false;
  return parsed.authority.toLowerCase() == target;
}
