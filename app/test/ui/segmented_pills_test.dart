import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/ui/segmented_pills.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final medium = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Medium.otf',
    );
    final bold = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.otf',
    );
    final loader = FontLoader('IBMPlexSansArabic')
      ..addFont(Future.value(medium))
      ..addFont(Future.value(bold));
    await loader.load();
  });

  Future<void> pumpTabs(WidgetTester tester, List<String> labels) async {
    // 300px pane, 16px row padding, 32px close control.
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 252,
              child: SegmentedPills(
                fitLabels: true,
                labels: labels,
                selectedIndex: labels.length - 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('contents titles stay whole in the wide sidebar', (tester) async {
    const labels = ['الفهرس', 'العلامات', 'التظليلات', 'الملاحظات'];
    await pumpTabs(tester, labels);
    expect(tester.takeException(), isNull);
    for (final label in labels) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });

  testWidgets('counted titles stay whole in the wide sidebar', (tester) async {
    const labels = ['الفهرس', 'العلامات 12', 'التظليلات 12', 'الملاحظات 12'];
    await pumpTabs(tester, labels);
    expect(tester.takeException(), isNull);
    for (final label in labels) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });
}
