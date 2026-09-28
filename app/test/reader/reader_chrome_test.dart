import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/features/reader/reader_chrome.dart';

void main() {
  ReaderChromeController open() => ReaderChromeController();

  bool tap(
    ReaderChromeController chrome, {
    double distance = 0,
    Duration elapsed = const Duration(milliseconds: 40),
    bool selectionWasActive = false,
    bool interactiveTarget = false,
  }) {
    return chrome.onPointerTap(
      distance: distance,
      elapsed: elapsed,
      selectionWasActive: selectionWasActive,
      interactiveTarget: interactiveTarget,
    );
  }

  test('opening a book shows chrome', () {
    expect(open().visible, isTrue);
  });

  test('a short tap toggles chrome both ways', () {
    final chrome = open();
    expect(tap(chrome), isTrue);
    expect(chrome.visible, isFalse);
    expect(tap(chrome), isTrue);
    expect(chrome.visible, isTrue);
  });

  test(
    'tap is ignored when a selection was active or the target is a badge',
    () {
      final selected = open();
      expect(tap(selected, selectionWasActive: true), isFalse);
      expect(selected.visible, isTrue);

      final badge = open();
      expect(tap(badge, interactiveTarget: true), isFalse);
      expect(badge.visible, isTrue);
    },
  );

  test('a moved pointer or a long press does not toggle', () {
    final swiped = open();
    expect(tap(swiped, distance: ReaderChromeController.tapSlop + 1), isFalse);
    expect(swiped.visible, isTrue);

    final held = open();
    expect(
      tap(
        held,
        elapsed:
            ReaderChromeController.tapMaxDuration +
            const Duration(milliseconds: 1),
      ),
      isFalse,
    );
    expect(held.visible, isTrue);
  });

  test('a page-index change hides chrome and the same index does not', () {
    final chrome = open();
    expect(chrome.onPageIndexChanged(from: 2, to: 2), isFalse);
    expect(chrome.visible, isTrue);
    expect(chrome.onPageIndexChanged(from: 2, to: 3), isTrue);
    expect(chrome.visible, isFalse);
    expect(chrome.onPageIndexChanged(from: 3, to: 4), isFalse);
    expect(chrome.visible, isFalse);
  });

  test('scrubber drag keeps chrome until release', () {
    final chrome = open();
    chrome.onScrubStart();
    expect(chrome.onPageIndexChanged(from: 0, to: 5), isFalse);
    expect(chrome.visible, isTrue);
    expect(chrome.scrubbing, isTrue);
    expect(chrome.onScrubEnd(), isTrue);
    expect(chrome.scrubbing, isFalse);
    expect(chrome.visible, isFalse);
  });

  test(
    'continuous scroll past the threshold hides; inner page scroll does not',
    () {
      final continuous = open();
      expect(continuous.onContinuousScrollDelta(20), isFalse);
      expect(continuous.visible, isTrue);
      expect(continuous.onContinuousScrollDelta(30), isTrue);
      expect(continuous.visible, isFalse);

      final inner = open();
      expect(inner.onInnerPageScroll(12), isFalse);
      expect(inner.onInnerPageScroll(100), isFalse);
      expect(inner.visible, isTrue);
    },
  );
}
