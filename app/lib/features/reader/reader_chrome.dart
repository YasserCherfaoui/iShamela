/// SPEC-026 — whether reader chrome is on screen.
///
/// Pure state. The reader widget applies it to the bars, panes, and system UI.
class ReaderChromeController {
  /// Open starts visible. Not persisted.
  bool visible = true;

  /// True while the page scrubber thumb is down.
  bool scrubbing = false;

  /// True while a non-collapsed text selection is active.
  bool selectionActive = false;

  double _continuousAccum = 0;

  /// Pointer travel beyond this is a swipe or scroll, not a tap.
  static const double tapSlop = 18;

  /// Presses longer than this are long-presses, not taps.
  static const Duration tapMaxDuration = Duration(milliseconds: 300);

  /// Continuous-list scroll that hides chrome (logical pixels).
  static const double continuousScrollThreshold = 48;

  /// Bar show/hide animation. Zero when the platform asks to reduce motion.
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Short tap on the page body. Returns whether [visible] changed.
  ///
  /// [selectionWasActive] is the selection state at pointer-down, not after
  /// the tap has cleared it.
  bool onPointerTap({
    required double distance,
    required Duration elapsed,
    required bool selectionWasActive,
    required bool interactiveTarget,
  }) {
    if (selectionWasActive || interactiveTarget) return false;
    if (elapsed > tapMaxDuration) return false;
    if (distance > tapSlop) return false;
    visible = !visible;
    return true;
  }

  /// Page index changed after open. No-op while [scrubbing] or if [from] == [to].
  bool onPageIndexChanged({required int from, required int to}) {
    if (from == to || scrubbing || !visible) return false;
    visible = false;
    return true;
  }

  void onScrubStart() {
    scrubbing = true;
  }

  /// Thumb up. Hides chrome even if the index did not change.
  bool onScrubEnd() {
    scrubbing = false;
    _continuousAccum = 0;
    if (!visible) return false;
    visible = false;
    return true;
  }

  /// User scroll of the continuous list. Inner print-page scrolls must not
  /// call this (see [onInnerPageScroll]).
  bool onContinuousScrollDelta(double delta) {
    _continuousAccum += delta;
    if (_continuousAccum.abs() < continuousScrollThreshold) return false;
    _continuousAccum = 0;
    if (!visible) return false;
    visible = false;
    return true;
  }

  void onContinuousScrollEnd() {
    _continuousAccum = 0;
  }

  /// Scrolling inside one print page. Never hides chrome.
  bool onInnerPageScroll(double delta) {
    return delta.isNaN && false;
  }
}
