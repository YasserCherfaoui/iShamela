import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/auth/provider_sign_in.dart';
import 'package:ishamela/core/config.dart';

void main() {
  test('appleWebRedirectUri drops route, query, and fragment', () {
    expect(
      appleWebRedirectUri(Uri.parse('https://app.ishamela.online/')),
      Uri.parse('https://app.ishamela.online/'),
    );
    expect(
      appleWebRedirectUri(Uri.parse('https://app.ishamela.online/#/auth')),
      Uri.parse('https://app.ishamela.online/'),
    );
    expect(
      appleWebRedirectUri(
        Uri.parse('https://yassercherfaoui.github.io/iShamela/'),
      ),
      Uri.parse('https://yassercherfaoui.github.io/iShamela/'),
    );
    expect(
      appleWebRedirectUri(
        Uri.parse('https://yassercherfaoui.github.io/iShamela/#/auth'),
      ),
      Uri.parse('https://yassercherfaoui.github.io/iShamela/'),
    );
    expect(
      appleWebRedirectUri(
        Uri.parse('https://app.ishamela.online/iShamela?x=1#/auth'),
      ),
      Uri.parse('https://app.ishamela.online/iShamela/'),
    );
    expect(
      appleWebRedirectUri(Uri.parse('https://app.ishamela.online:443/')),
      Uri.parse('https://app.ishamela.online/'),
    );
  });

  test('apple web redirect is public https only', () {
    expect(
      appleWebRedirectIsPublic(Uri.parse('https://app.ishamela.online/')),
      isTrue,
    );
    expect(
      appleWebRedirectIsPublic(Uri.parse('http://localhost:8080/')),
      isFalse,
    );
    expect(
      appleWebRedirectIsPublic(Uri.parse('https://127.0.0.1/')),
      isFalse,
    );
    expect(
      appleWebRedirectIsPublic(Uri.parse('https://localhost/')),
      isFalse,
    );
  });

  test('apple web options are omitted off the web', () {
    expect(
      appleWebAuthentication(
        isWeb: false,
        page: Uri.parse('http://localhost/'),
      ),
      isNull,
    );
    final web = appleWebAuthentication(
      isWeb: true,
      page: Uri.parse('https://app.ishamela.online/#/auth'),
    );
    expect(web?.clientId, appleWebServiceId);
    expect(web?.redirectUri, Uri.parse('https://app.ishamela.online/'));
    expect(
      () => appleWebAuthentication(
        isWeb: true,
        page: Uri.parse('http://localhost:8080/'),
      ),
      throwsA(isA<AuthUnavailable>()),
    );
  });

  test('web Google and Apple use the Firebase popup', () {
    final source = File(
      'lib/core/auth/auth_controller.dart',
    ).readAsStringSync();
    expect(source, contains('signInWithPopup(GoogleAuthProvider())'));
    expect(source, contains("OAuthProvider('apple.com')"));
    expect(source, contains('signInWithPopup(apple)'));
    expect(source, isNot(contains('signInWithGoogle')));
    expect(source, isNot(contains('signInWithApple')));
  });

  test('index.html names the web Google client and loads Apple JS', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('name="google-signin-client_id"'));
    expect(html, contains(googleWebClientId));
    expect(
      html,
      contains(
        'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js',
      ),
    );
    expect(appleWebServiceId, 'online.ishamela.web');
    expect(appleBundleId, 'org.ishamela.ishamela');
  });
}
