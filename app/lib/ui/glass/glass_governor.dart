/// First 120 frames after glass turns on (SPEC-027 §6).
class GlassFrameGovernor {
  int frames = 0;
  int slow = 0;
  bool tripped = false;

  static const sampleSize = 120;

  /// Budget is 16 ms, or 8 ms on a 120 Hz display.
  static Duration budgetFor({required bool highRefreshRate}) {
    return highRefreshRate
        ? const Duration(milliseconds: 8)
        : const Duration(milliseconds: 16);
  }

  /// Records one frame. Returns true the moment the governor trips.
  bool record(Duration frame, {required Duration budget}) {
    if (tripped || frames >= sampleSize) return false;
    frames++;
    if (frame > budget) slow++;
    if (frames == sampleSize && slow / frames > 0.10) {
      tripped = true;
      return true;
    }
    return false;
  }

  void reset() {
    frames = 0;
    slow = 0;
    tripped = false;
  }
}
