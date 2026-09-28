import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/glass/interface_style.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

const glassGovernorNoticeKey = 'prefs.glassGovernorNoticeShown';

/// Installs [GlassStyleScope], the frame governor, and the one-time notice.
class GlassRuntime extends ConsumerStatefulWidget {
  const GlassRuntime({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlassRuntime> createState() => _GlassRuntimeState();
}

class _GlassRuntimeState extends ConsumerState<GlassRuntime> {
  bool _highRefresh = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rate = View.maybeOf(context)?.display.refreshRate ?? 60;
    _highRefresh = rate >= 119;
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    if (ref.read(interfaceStyleProvider) != InterfaceStyle.liquidGlass) return;
    if (ref.read(glassGovernorProvider).tripped) return;
    final notifier = ref.read(glassGovernorProvider.notifier);
    for (final timing in timings) {
      final tripped = notifier.record(
        timing.totalSpan,
        highRefreshRate: _highRefresh,
      );
      if (tripped) {
        _maybeSuppressNotice();
        break;
      }
    }
  }

  Future<void> _maybeSuppressNotice() async {
    final db = await ref.read(stateDatabaseProvider.future);
    if (db.setting(glassGovernorNoticeKey) == '1') {
      ref.read(glassGovernorProvider.notifier).dismissNotice();
    }
  }

  Future<void> _dismiss() async {
    ref.read(glassGovernorProvider.notifier).dismissNotice();
    final db = await ref.read(stateDatabaseProvider.future);
    db.setSetting(glassGovernorNoticeKey, '1');
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(interfaceStyleProvider);
    final capability = ref.watch(glassCapabilityProvider);
    final atmosphere = ref.watch(readingAtmosphereProvider);
    final depth = ref.watch(glassSheetDepthProvider);
    final notice = ref.watch(glassGovernorProvider).noticeVisible;
    return GlassStyleScope(
      style: style,
      capability: capability,
      atmosphere: atmosphere,
      sheetDepth: depth,
      child: Stack(
        children: [
          widget.child,
          if (notice)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _GovernorNotice(onDismiss: _dismiss),
            ),
        ],
      ),
    );
  }
}

class _GovernorNotice extends StatelessWidget {
  const _GovernorNotice({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.glassSimplifiedNotice,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 13,
                  color: t.ink,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: t.muted, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
