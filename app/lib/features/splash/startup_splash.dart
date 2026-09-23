import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool get _ready => _workDone && _minHoldDone;

  @override
  void initState() {
    super.initState();
    _minHold = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _minHoldDone = true);
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
      await Future.any<void>([
        () async {
          await ref.read(appPathsProvider.future);
          await ref.read(stateDatabaseProvider.future);
        }(),
        // Never leave the user stuck on the progress bar if paths/DB hang.
        Future<void>.delayed(const Duration(seconds: 2)),
      ]);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _workDone = true);
  }

  void _onStartReading() {
    if (!_ready || _hiding || _gone) return;
    // Land on Home (SPEC-023).
    ref.read(homeTabIndexProvider.notifier).go(HomeTabs.home);
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
            child: _SplashBody(
              ready: _ready,
              onStartReading: _onStartReading,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody({
    required this.ready,
    required this.onStartReading,
  });

  final bool ready;
  final VoidCallback onStartReading;

  static const _field = Color(0xFF0E3B30);
  static const _paper = Color(0xFFF2E8CF);
  static const _gold = Color(0xFFC6A15B);

  static const _overlay = SystemUiOverlayStyle(
    statusBarColor: _field,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _field,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // MaterialApp.builder sits above the navigator Scaffold — without Material,
    // every Text paints the yellow "no Material" underline.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Material(
        color: _field,
        child: Scaffold(
          backgroundColor: _field,
          body: SafeArea(
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        color: _paper,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.brandName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 2.5,
                        color: _gold,
                        decoration: TextDecoration.none,
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
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: ready
                          ? SizedBox(
                              key: const ValueKey('cta'),
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: onStartReading,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: _field,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  l10n.startReading,
                                  style: const TextStyle(
                                    fontFamily: kFontUi,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              key: const ValueKey('loading'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kFontUi,
                                    fontSize: 11,
                                    color: _paper.withValues(alpha: 0.7),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
