sealed class IncomingAppLink {
  const IncomingAppLink();
  String get identity;
}

final class IncomingInvite extends IncomingAppLink {
  const IncomingInvite(this.code, {required this.universalLink});
  final String code;
  final bool universalLink;
  @override
  String get identity => 'invite:$code';
}

final class IncomingPayment extends IncomingAppLink {
  const IncomingPayment(this.entry);
  final String entry;
  @override
  String get identity => 'payment:$entry';
}

/// Admission is shared by routing and attribution, including install referrers.
bool isValidatedMobioAppLinkOrigin(Uri uri) {
  if (uri.toString().length > 4096 ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment ||
      uri.queryParametersAll.values.any((values) => values.length != 1)) {
    return false;
  }
  return (uri.scheme == 'https' && uri.host == 'mobio.ikanisa.com') ||
      (uri.scheme == 'mobio' && uri.host == 'biopay' && uri.path == '/nfc');
}

IncomingInvite? parseIncomingInvite(Uri uri) {
  if (!isValidatedMobioAppLinkOrigin(uri) || uri.scheme != 'https') return null;
  String? code;
  if (uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'invite' &&
      uri.query.isEmpty) {
    code = uri.pathSegments[1];
  } else if (uri.path == '/' || uri.path == '/home') {
    if (uri.queryParameters.containsKey('ref') &&
        uri.queryParameters.containsKey('code'))
      return null;
    code = uri.queryParameters['ref'] ?? uri.queryParameters['code'];
  }
  if (code == null) return null;
  code = code.trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9_-]{1,64}$').hasMatch(code)) return null;
  return IncomingInvite(code, universalLink: true);
}
