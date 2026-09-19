import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Flutter-layer splash while startup work runs (SPEC-020 SP-02..04).
class StartupSplashGate extends ConsumerStatefulWidget {
  const StartupSplashGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends ConsumerState<StartupSplashGate> {
  bool _workDone = false;
  bool _minHoldDone = false;
  bool _hiding = false;
  bool _gone = false;
  Timer? _minHold;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _minHold = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _minHoldDone = true);
      _tryHide();
    });
    _kickoff();
  }

  @override
  void dispose() {
    _minHold?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  Future<void> _kickoff() async {
    try {
      await ref.read(appPathsProvider.future);
      await ref.read(stateDatabaseProvider.future);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _workDone = true);
    _tryHide();
  }

  void _tryHide() {
    if (!_workDone || !_minHoldDone || _hiding || _gone) return;
    _hiding = true;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final fade = reduce ? Duration.zero : const Duration(milliseconds: 200);
    setState(() {});
    _fadeTimer?.cancel();
    _fadeTimer = Timer(fade, () {
      if (!mounted) return;
      setState(() {
        _gone = true;
        _hiding = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;

    final reduce = MediaQuery.disableAnimationsOf(context);
    final opacity = _hiding ? 0.0 : 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm providers under the splash without flashing chrome.
        IgnorePointer(child: Opacity(opacity: 0, child: widget.child)),
        IgnorePointer(
          ignoring: _hiding,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: const _SplashBody(),
          ),
        ),
      ],
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  static const _field = Color(0xFF0E3B30);
  static const _paper = Color(0xFFF2E8CF);
  static const _gold = Color(0xFFC6A15B);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: _field,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 1,
                  color: _gold.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 28),
                Image.asset(
                  'assets/brand/generated/splash/splash.png',
                  width: 96,
                  height: 96,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 20),
                Text(
                  'الشاملة',
                  style: TextStyle(
                    fontFamily: kFontAmiri,
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    color: _paper,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.brandName,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 2.5,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: _paper.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 132,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFF1E5040),
                      color: _gold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.preparingLibrary,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 11,
                    color: _paper.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
