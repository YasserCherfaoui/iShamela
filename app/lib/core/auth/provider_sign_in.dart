import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/config.dart';

/// Apple’s web return URL for [page] (SPEC-031). Query and fragment are dropped.
Uri appleWebRedirectUri(Uri page) {
  final dropPort = !page.hasPort ||
      (page.scheme == 'https' && page.port == 443) ||
      (page.scheme == 'http' && page.port == 80);
  var path = page.path;
  if (path.isEmpty) path = '/';
  if (!path.endsWith('/')) path = '$path/';
  return Uri(
    scheme: page.scheme,
    host: page.host,
    port: dropPort ? null : page.port,
    path: path,
  );
}

/// Apple rejects localhost and non-HTTPS return URLs (SPEC-031).
bool appleWebRedirectIsPublic(Uri page) {
  final host = page.host.toLowerCase();
  if (page.scheme != 'https' || host.isEmpty) return false;
  return host != 'localhost' && host != '127.0.0.1' && host != '::1';
}

/// Web-only Apple JS options. Null on native. Throws [AuthUnavailable] for a
/// local web origin.
({String clientId, Uri redirectUri})? appleWebAuthentication({
  required bool isWeb,
  required Uri page,
}) {
  if (!isWeb) return null;
  if (!appleWebRedirectIsPublic(page)) {
    throw AuthUnavailable(
      'Apple Sign In on the web requires a public HTTPS origin',
    );
  }
  return (
    clientId: appleWebServiceId,
    redirectUri: appleWebRedirectUri(page),
  );
}
