import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/web/shell_freshness.dart';

void main() {
  test('shellBuildIsStale ignores empty ids and matches equals', () {
    expect(shellBuildIsStale('', 'abc'), isFalse);
    expect(shellBuildIsStale('abc', null), isFalse);
    expect(shellBuildIsStale('abc', ''), isFalse);
    expect(shellBuildIsStale('abc', '   '), isFalse);
    expect(shellBuildIsStale('abc', 'abc'), isFalse);
    expect(shellBuildIsStale('abc', ' abc '), isFalse);
    expect(shellBuildIsStale('old', 'new'), isTrue);
  });

  test('index.html gates bootstrap on the build id placeholder', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('name="ishamela-build-id"'));
    expect(html, contains('content="__ISHAMELA_BUILD_ID__"'));
    expect(html, contains('ishamela-build-id'));
    expect(html, contains('ishamela-shell-reloaded'));
    expect(html, contains("flutter-"));
    final gate = html.indexOf('ishamela-build-id');
    final bootstrap = html.indexOf('flutter_bootstrap.js');
    expect(gate, greaterThan(-1));
    expect(bootstrap, greaterThan(gate));
    expect(html, isNot(contains('<script src="flutter_bootstrap.js"')));
  });

  test('vercel shell paths revalidate and are not immutable', () {
    final vercel =
        jsonDecode(File('../vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final encoded = jsonEncode(vercel);
    expect(encoded, isNot(contains('immutable')));
    final headers = (vercel['headers'] as List).cast<Map<String, dynamic>>();
    const shell = [
      '/',
      'index.html',
      'flutter_bootstrap.js',
      'flutter.js',
      'flutter_service_worker.js',
      'main.dart.js',
      'version.json',
      'shell-version.json',
      'manifest.json',
      'AssetManifest.bin.json',
      'FontManifest.json',
    ];
    for (final name in shell) {
      final rule = headers.cast<Map<String, dynamic>?>().firstWhere(
        (entry) => (entry!['source'] as String).contains(name == '/' ? '"/"' : name) ||
            (name == '/' && entry['source'] == '/'),
        orElse: () => null,
      );
      expect(rule, isNotNull, reason: name);
      final value =
          ((rule!['headers'] as List).first as Map)['value'] as String;
      expect(value, 'public, max-age=0, must-revalidate', reason: name);
    }
    final images = headers.firstWhere(
      (entry) => (entry['source'] as String).contains('woff2'),
    );
    expect(
      ((images['headers'] as List).first as Map)['value'],
      'public, max-age=86400',
    );
  });

  test('web builds stamp the shell after flutter build web', () {
    final vercelBuild = File('../scripts/vercel-build.sh').readAsStringSync();
    final workflow = File(
      '../.github/workflows/build-release.yml',
    ).readAsStringSync();
    for (final source in [vercelBuild, workflow]) {
      expect(source, contains('--dart-define=APP_BUILD_ID='));
      expect(source, contains('stamp-web-build.sh'));
      expect(source, isNot(contains('--pwa-strategy=none')));
      final buildAt = source.indexOf('flutter build web');
      final stampAt = source.indexOf('stamp-web-build.sh');
      expect(stampAt, greaterThan(buildAt));
    }
  });
}
