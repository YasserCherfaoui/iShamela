import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand icon generation inventory matches SPEC-020 BR-04/05/06', () {
    final inventory = File('assets/brand/generated/inventory.txt');
    expect(inventory.existsSync(), isTrue);
    final lines = inventory
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    const required = {
      'master-64.png',
      'master-128.png',
      'master-256.png',
      'master-512.png',
      'master-1024.png',
      'splash/splash.png',
      'splash/splash-android12.png',
      'android/mipmap-xxxhdpi/ic_launcher_foreground.png',
      'android/mipmap-xxxhdpi/ic_launcher_monochrome.png',
      'ios/icon-1024.png',
      'web/favicon-32.png',
      'web/maskable-512.png',
      'desktop/icon-512.png',
    };
    expect(lines, containsAll(required));
    for (final rel in required) {
      expect(
        File('assets/brand/generated/$rel').existsSync(),
        isTrue,
        reason: rel,
      );
    }
  });
}
