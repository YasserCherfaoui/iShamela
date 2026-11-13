import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/ui/jump_sheet.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

void main() {
  testWidgets('showJumpSheet renders part chips and passes selected part', (
    tester,
  ) async {
    String? submittedRaw;
    String? submittedPart;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildIshamelaTheme(ReadingAtmosphere.paper),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showJumpSheet(
                context: context,
                title: 'الانتقال',
                fieldHint: 'رقم الصفحة',
                goLabel: 'انتقال',
                cancelLabel: 'إلغاء',
                parts: const ['1', '2', '3'],
                initialPart: '1',
                onGoWithPart: (raw, part) async {
                  submittedRaw = raw;
                  submittedPart = part;
                  return true;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ج1'), findsOneWidget);
    expect(find.text('ج2'), findsOneWidget);
    expect(find.text('ج3'), findsOneWidget);

    await tester.tap(find.text('ج2'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();

    expect(submittedRaw, '45');
    expect(submittedPart, '2');
  });
}
