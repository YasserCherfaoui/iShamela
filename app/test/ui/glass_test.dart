import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/ui/glass/appearance_prefs.dart';
import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_capability.dart';
import 'package:ishamela/ui/glass/glass_color_matrix.dart';
import 'package:ishamela/ui/glass/glass_contrast.dart';
import 'package:ishamela/ui/glass/glass_governor.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/glass/interface_style.dart';
import 'package:ishamela/ui/jump_sheet.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

void main() {
  setUp(GlassBackdropBudget.resetForTest);

  group('interface style', () {
    test('fresh install is manuscript', () {
      expect(InterfaceStyle.fromId(null), InterfaceStyle.manuscript);
      expect(InterfaceStyle.manuscript.id, 'manuscript');
      expect(InterfaceStyle.settingsKey, 'prefs.interfaceStyle');
    });

    test('round-trips liquid glass', () {
      expect(
        InterfaceStyle.fromId(InterfaceStyle.liquidGlass.id),
        InterfaceStyle.liquidGlass,
      );
    });
  });

  group('appearance LWW', () {
    test('remote wins over the local default', () {
      const local = AppearancePref.defaults;
      const remote = AppearancePref(
        style: InterfaceStyle.liquidGlass,
        updatedAt: 50,
      );
      expect(
        chooseAppearance(local: local, remote: remote).style,
        InterfaceStyle.liquidGlass,
      );
    });

    test('a later local choice beats an older remote value', () {
      const local = AppearancePref(
        style: InterfaceStyle.liquidGlass,
        updatedAt: 80,
      );
      const remote = AppearancePref(
        style: InterfaceStyle.manuscript,
        updatedAt: 40,
      );
      expect(
        chooseAppearance(local: local, remote: remote).style,
        InterfaceStyle.liquidGlass,
      );
    });

    test('missing remote keeps the local choice', () {
      const local = AppearancePref(
        style: InterfaceStyle.liquidGlass,
        updatedAt: 10,
      );
      expect(chooseAppearance(local: local, remote: null).style, local.style);
    });

    test('equal timestamps keep the local choice', () {
      const local = AppearancePref(
        style: InterfaceStyle.manuscript,
        updatedAt: 10,
      );
      const remote = AppearancePref(
        style: InterfaceStyle.liquidGlass,
        updatedAt: 10,
      );
      expect(chooseAppearance(local: local, remote: remote).style, local.style);
    });
  });

  group('capability', () {
    GlassCapability resolve({
      InterfaceStyle style = InterfaceStyle.liquidGlass,
      bool apple = false,
      bool native = false,
      bool reduce = false,
      bool battery = false,
      bool governor = false,
      bool backdrop = true,
    }) {
      return resolveGlassCapability(
        GlassCapabilityInput(
          style: style,
          applePlatform: apple,
          nativeAvailable: native,
          reduceTransparency: reduce,
          batterySaver: battery,
          governorTripped: governor,
          elementBackdropWorks: backdrop,
        ),
      );
    }

    test('iOS 26 with the native API is native', () {
      expect(resolve(apple: true, native: true), GlassCapability.native);
    });

    test('Apple below OS 26 is drawn', () {
      expect(resolve(apple: true, native: false), GlassCapability.drawn);
    });

    test('Android and web are drawn', () {
      expect(resolve(), GlassCapability.drawn);
    });

    test('reduce transparency, battery saver, and the governor frost', () {
      expect(resolve(apple: true, native: true, reduce: true), GlassCapability.frosted);
      expect(resolve(battery: true), GlassCapability.frosted);
      expect(resolve(governor: true), GlassCapability.frosted);
    });

    test('a native element that cannot sample Flutter falls back to drawn', () {
      expect(
        resolve(apple: true, native: true, backdrop: false),
        GlassCapability.drawn,
      );
    });
  });

  group('tokens', () {
    test('light, sepia, and night match the drawn recipe', () {
      expect(GlassTokens.light.blur, 28);
      expect(GlassTokens.light.saturation, 1.70);
      expect(GlassTokens.light.brightness, 1.05);
      expect(GlassTokens.light.tint, const Color(0x94FBF7EC));
      expect(GlassTokens.sepia.tint, const Color(0x99F1E5CC));
      expect(GlassTokens.sepia.foregroundGold, const Color(0xFF8F6A1F));
      expect(GlassTokens.night.blur, 24);
      expect(GlassTokens.night.foregroundInk, const Color(0xFFF2E8CF));
      expect(GlassTokens.night.foregroundAccent, const Color(0xFF8FC7AC));
      expect(GlassTokens.night.activeCapsule, const Color(0x24F2E8CF));
      expect(GlassTokens.light.radiusBar, 20);
      expect(GlassTokens.light.radiusSheet, 28);
      expect(GlassTokens.light.radiusPill, 999);
    });

    test('frosted clears blur and raises tint to 94%', () {
      final frosted = GlassTokens.light.frosted();
      expect(frosted.blur, 0);
      expect(frosted.saturation, 1);
      expect(frosted.tint.a, closeTo(0.94, 0.001));
      expect(frosted.foregroundInk, GlassTokens.light.foregroundInk);
    });

    test('blur sigma clamps device pixel ratio above 3', () {
      expect(glassBlurSigma(28, 2), closeTo(28 / 2.4, 0.001));
      expect(glassBlurSigma(28, 4), closeTo((28 / 2.4) * 3 / 4, 0.001));
      expect(glassBlurSigma(0, 2), 0);
    });

    test('saturation 1 and brightness 1 is identity', () {
      final matrix = glassColorMatrix(saturation: 1, brightness: 1);
      expect(matrix, [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    });
  });

  group('governor', () {
    test('more than 10% slow frames frosts the session', () {
      final governor = GlassFrameGovernor();
      final budget = GlassFrameGovernor.budgetFor(highRefreshRate: false);
      for (var i = 0; i < 107; i++) {
        expect(governor.record(const Duration(milliseconds: 10), budget: budget), isFalse);
      }
      for (var i = 0; i < 12; i++) {
        governor.record(const Duration(milliseconds: 20), budget: budget);
      }
      expect(
        governor.record(const Duration(milliseconds: 20), budget: budget),
        isTrue,
      );
      expect(governor.tripped, isTrue);
    });

    test('exactly 10% slow frames stays drawn', () {
      final governor = GlassFrameGovernor();
      final budget = GlassFrameGovernor.budgetFor(highRefreshRate: true);
      expect(budget, const Duration(milliseconds: 8));
      for (var i = 0; i < 108; i++) {
        governor.record(const Duration(milliseconds: 4), budget: budget);
      }
      for (var i = 0; i < 12; i++) {
        governor.record(const Duration(milliseconds: 9), budget: budget);
      }
      expect(governor.tripped, isFalse);
    });
  });

  group('contrast', () {
    test('labels on frosted light glass stay at least 4.5:1', () {
      final tokens = GlassTokens.light.frosted();
      const page = Color(0xFFF8F3E6);
      const ink = Color(0xFF1A1A1A);
      for (final fg in [
        tokens.foregroundInk,
        tokens.foregroundAccent,
      ]) {
        expect(
          worstGlassContrast(
            foreground: fg,
            tint: tokens.tint,
            page: page,
            ink: ink,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('a failing label raises the active capsule to 24%', () {
      final boosted = activeCapsuleForLabel(
        tokens: GlassTokens.light,
        foreground: const Color(0xFFDDDDDD),
        page: const Color(0xFFFFFFFF),
        ink: const Color(0xFFFFFFFF),
      );
      expect(boosted.a, closeTo(0.24, 0.001));
    });
  });

  testWidgets('manuscript glass surface has no backdrop filter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIshamelaTheme(ReadingAtmosphere.paper),
        home: const GlassStyleScope(
          style: InterfaceStyle.manuscript,
          capability: GlassCapability.drawn,
          atmosphere: ReadingAtmosphere.paper,
          sheetDepth: 0,
          child: GlassSurface(
            shape: GlassShape.bar(),
            child: Text('مخطوط'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('مخطوط'), findsOneWidget);
  });

  testWidgets('drawn glass blurs and frosted glass does not', (tester) async {
    Future<void> pump(GlassCapability capability) {
      return tester.pumpWidget(
        MaterialApp(
          theme: buildIshamelaTheme(ReadingAtmosphere.paper),
          home: GlassStyleScope(
            style: InterfaceStyle.liquidGlass,
            capability: capability,
            atmosphere: ReadingAtmosphere.paper,
            sheetDepth: 0,
            child: const GlassSurface(
              shape: GlassShape.pill(),
              child: SizedBox(width: 120, height: 48, child: Text('زجاج')),
            ),
          ),
        ),
      );
    }

    await pump(GlassCapability.drawn);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await pump(GlassCapability.frosted);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('an open sheet repaints chrome opaque', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIshamelaTheme(ReadingAtmosphere.sepia),
        home: const GlassStyleScope(
          style: InterfaceStyle.liquidGlass,
          capability: GlassCapability.drawn,
          atmosphere: ReadingAtmosphere.sepia,
          sheetDepth: 1,
          child: GlassSurface(
            shape: GlassShape.bar(),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('reader body is never a glass surface', () {
    final src = File('lib/features/reader/annotated_body.dart').readAsStringSync();
    expect(src.contains('GlassSurface'), isFalse);
    expect(src.contains('BackdropFilter'), isFalse);
  });

  testWidgets('closing the jump sheet does not reuse a disposed controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildIshamelaTheme(ReadingAtmosphere.paper),
          home: GlassStyleScope(
            style: InterfaceStyle.liquidGlass,
            capability: GlassCapability.drawn,
            atmosphere: ReadingAtmosphere.paper,
            sheetDepth: 0,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    showJumpSheet(
                      context: context,
                      title: 'الانتقال',
                      fieldHint: 'ص',
                      goLabel: 'اذهب',
                      cancelLabel: 'إلغاء',
                      onGo: (_) async => false,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader nav buttons on glass use the capsule fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIshamelaTheme(ReadingAtmosphere.paper),
        home: const GlassStyleScope(
          style: InterfaceStyle.liquidGlass,
          capability: GlassCapability.drawn,
          atmosphere: ReadingAtmosphere.paper,
          sheetDepth: 0,
          child: GlassSurface(
            shape: GlassShape.pill(),
            child: TonalIconButton(
              icon: Icons.chevron_left,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      GlassTokens.light.activeCapsule,
    );
  });

  testWidgets('reader nav buttons stay tonal in manuscript', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIshamelaTheme(ReadingAtmosphere.paper),
        home: const GlassStyleScope(
          style: InterfaceStyle.manuscript,
          capability: GlassCapability.drawn,
          atmosphere: ReadingAtmosphere.paper,
          sheetDepth: 0,
          child: TonalIconButton(icon: Icons.chevron_left, onPressed: _noop),
        ),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      IshamelaTokens.paperLight.green100,
    );
  });
}

void _noop() {}
