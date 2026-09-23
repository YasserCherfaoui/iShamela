import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/app.dart';

void main() {
  testWidgets('app builds with Arabic catalog tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IshamelaApp()));
    await tester.pump();
    expect(find.text('يجري تجهيز المكتبة…'), findsOneWidget);
    // Min-hold 400ms + kickoff timeout ≤2s → CTA.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('ابدأ القراءة'), findsOneWidget);
    await tester.tap(find.text('ابدأ القراءة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('الرئيسية'), findsWidgets);
  });
}
