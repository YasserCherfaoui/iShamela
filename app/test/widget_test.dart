import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/app.dart';

void main() {
  testWidgets('app builds with Arabic catalog tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IshamelaApp()));
    await tester.pump(); // first frame
    // Allow async providers to settle without hanging on network.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('الفهرس'), findsWidgets);
  });
}
