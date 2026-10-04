import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/sync/progress_policy.dart';

void main() {
  test('a peek shorter than 8 seconds does not qualify', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final policy = ProgressPolicy(clock: () => now);
    policy.land(bookId: 1, ordinal: 0, page: 300);
    now = now.add(const Duration(seconds: 3));
    expect(policy.checkDwell(), isFalse);
  });

  test('eight seconds in the foreground qualifies once', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final policy = ProgressPolicy(clock: () => now);
    policy.land(bookId: 1, ordinal: 0, page: 10);
    now = now.add(const Duration(seconds: 8));
    expect(policy.checkDwell(), isTrue);
    expect(policy.checkDwell(), isFalse);
  });

  test('time in the background does not count toward dwell', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final policy = ProgressPolicy(clock: () => now);
    policy.land(bookId: 1, ordinal: 0, page: 10);
    now = now.add(const Duration(seconds: 3));
    policy.setForeground(false);
    now = now.add(const Duration(seconds: 30));
    expect(policy.checkDwell(), isFalse);
    policy.setForeground(true);
    now = now.add(const Duration(seconds: 5));
    expect(policy.checkDwell(), isTrue);
  });

  test('two consecutive turns qualify, and further turns keep qualifying', () {
    final policy = ProgressPolicy();
    policy.land(bookId: 1, ordinal: 0, page: 1);
    expect(policy.onTurn(bookId: 1, ordinal: 1, page: 2), isFalse);
    expect(policy.onTurn(bookId: 1, ordinal: 2, page: 3), isTrue);
    expect(policy.onTurn(bookId: 1, ordinal: 3, page: 4), isTrue);
  });

  test('a jump to another page does not qualify', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final policy = ProgressPolicy(clock: () => now);
    policy.land(bookId: 1, ordinal: 0, page: 1);
    now = now.add(const Duration(seconds: 7));
    expect(policy.onTurn(bookId: 1, ordinal: 20, page: 300), isFalse);
    expect(policy.checkDwell(), isFalse);
  });

  test('reversing direction starts the streak over', () {
    final policy = ProgressPolicy();
    policy.land(bookId: 1, ordinal: 5, page: 5);
    expect(policy.onTurn(bookId: 1, ordinal: 6, page: 6), isFalse);
    expect(policy.onTurn(bookId: 1, ordinal: 5, page: 5), isFalse);
    expect(policy.onTurn(bookId: 1, ordinal: 4, page: 4), isTrue);
  });
}
