import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/app.dart';

void main() {
  testWidgets('app builds with Arabic catalog tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IshamelaApp()));
    await tester.pump(); // first frame
    // Splash min-hold 400ms + fade 200ms; settle async providers.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('الفهرس'), findsWidgets);
  });
}
