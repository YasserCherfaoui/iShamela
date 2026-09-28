import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wide reader: side panes are siblings of the page. Toggling them (the same
/// setState the chrome toggle performs) must not recreate the [PageView] on
/// an older page.
void main() {
  testWidgets(
    'showing the side panes keeps the page read while they were hidden',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final host = GlobalKey<_HostState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: host, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpToPage(4);
      await tester.pumpAndSettle();
      expect(controller.page?.round(), 4);

      host.currentState!.setPanes(false);
      await tester.pumpAndSettle();
      expect(controller.page?.round(), 4);

      controller.jumpToPage(7);
      await tester.pumpAndSettle();
      expect(controller.page?.round(), 7);

      host.currentState!.setPanes(true);
      await tester.pumpAndSettle();
      expect(controller.page?.round(), 7);
    },
  );
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.controller});

  final PageController controller;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _panes = true;

  void setPanes(bool value) => setState(() => _panes = value);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          if (_panes) const SizedBox(width: 300),
          if (_panes) const VerticalDivider(width: 1),
          Expanded(
            key: const ValueKey<String>('reader-column'),
            child: PageView.builder(
              controller: widget.controller,
              itemCount: 10,
              itemBuilder: (_, i) => Text('page $i'),
            ),
          ),
          if (_panes) const VerticalDivider(width: 1),
          if (_panes) const SizedBox(width: 300),
        ],
      ),
    );
  }
}
