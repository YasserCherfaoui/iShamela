import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/core/search/normalizer.dart';

List<Map<String, String>> loadVectors() {
  final file = File('../shared/norm_test_vectors.jsonl');
  if (!file.existsSync()) {
    throw StateError('missing golden file at ${file.absolute.path}');
  }
  return file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        final row = jsonDecode(line) as Map<String, dynamic>;
        return {
          'in': row['in'] as String,
          'out': row['out'] as String,
          'note': row['note'] as String,
        };
      })
      .toList();
}

void main() {
  late final List<Map<String, String>> vectors;

  setUpAll(() {
    vectors = loadVectors();
  });

  test('golden file has at least 40 vectors', () {
    expect(vectors.length, greaterThanOrEqualTo(40));
  });

  test('normVersion is 1.0.0', () {
    expect(normVersion, '1.0.0');
  });

  test('all golden vectors', () {
    final failures = <String>[];
    for (var i = 0; i < vectors.length; i++) {
      final row = vectors[i];
      final got = normalize(row['in']!);
      if (got != row['out']) {
        failures.add('#${i + 1} ${row['note']}: ${jsonEncode(got)} != ${jsonEncode(row['out'])}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('idempotence on all vectors', () {
    final failures = <String>[];
    for (var i = 0; i < vectors.length; i++) {
      final row = vectors[i];
      final once = normalize(row['in']!);
      final twice = normalize(once);
      if (once != twice) {
        failures.add('#${i + 1} ${row['note']}: ${jsonEncode(once)} != ${jsonEncode(twice)}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
