import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ishamela/l10n/app_localizations.dart';

/// Web is best-effort (ADR-001 / docs/ZSTD.md): SQLite FFI + zstd native
/// plugins are not wired for WASM yet. Keep a compileable entry so
/// `flutter build web` succeeds without pulling `dart:ffi` sqlite bindings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _WebUnsupportedApp());
}

class _WebUnsupportedApp extends StatelessWidget {
  const _WebUnsupportedApp();

  static const _field = Color(0xFF0E3B30);
  static const _paper = Color(0xFFF2E8CF);
  static const _gold = Color(0xFFC6A15B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        backgroundColor: _field,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/brand/generated/master-128.png',
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: 24),
                const Text(
                  'الشاملة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    color: _paper,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'iSHAMELA',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Web is best-effort — use the Android, iOS, macOS, or Windows app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    color: _paper.withValues(alpha: 0.85),
                    height: 1.4,
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
