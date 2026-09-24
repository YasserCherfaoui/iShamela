import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/reading_diff.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_welcome_screen.dart';
import 'package:ishamela/features/library/history_page.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

Future<void> showHomeSyncSheet(BuildContext context) {
  final t = IshamelaTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.72;
      return SizedBox(height: height, child: const _HomeSyncSheet());
    },
  );
}

class _HomeSyncSheet extends ConsumerStatefulWidget {
  const _HomeSyncSheet();

  @override
  ConsumerState<_HomeSyncSheet> createState() => _HomeSyncSheetState();
}

class _HomeSyncSheetState extends ConsumerState<_HomeSyncSheet> {
  bool _loading = true;
  bool _syncing = false;
  bool _failed = false;
  SyncState? _sync;
  List<ReadingProgressDiff> _diffs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    if (!auth.isVerified) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = false;
          _diffs = const [];
          _sync = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final db = await ref.read(stateDatabaseProvider.future);
      final diffs = await ref
          .read(authProvider.notifier)
          .previewReadingDiff(db);
      final sync = db.getSyncState();
      if (!mounted) return;
      setState(() {
        _diffs = diffs;
        _sync = sync;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final db = await ref.read(stateDatabaseProvider.future);
      await ref.read(authProvider.notifier).syncNow(db);
      ref.read(readingSyncRevisionProvider.notifier).bump();
    } catch (_) {
      // syncNow records the error on the local sync row.
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final auth = ref.watch(authProvider);
    final verified = auth.isVerified;
    final catalog = ref
        .watch(catalogRepositoryProvider)
        .maybeWhen(data: (c) => c, orElse: () => null);
    final locale = Localizations.localeOf(context);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeSyncTitle,
                    style: TextStyle(
                      fontFamily: kFontAmiri,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: t.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                if (!verified)
                  Text(
                    l10n.homeSyncSignIn,
                    style: TextStyle(fontFamily: kFontUi, color: t.ink),
                  )
                else if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Text(
                    _statusLine(l10n),
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 13,
                      color: t.muted,
                    ),
                  ),
                  if (_sync?.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.profileSyncError,
                      style: TextStyle(fontFamily: kFontUi, color: t.danger),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_failed)
                    Text(
                      l10n.homeSyncLoadFailed,
                      style: TextStyle(fontFamily: kFontUi, color: t.ink),
                    )
                  else if (_diffs.isEmpty)
                    Text(
                      l10n.homeSyncInSync,
                      style: TextStyle(fontFamily: kFontUi, color: t.ink),
                    )
                  else
                    for (final diff in _diffs)
                      _DiffRow(
                        title:
                            catalog?.bookById(diff.bookId)?.title ??
                            '${diff.bookId}',
                        kind: _kindLabel(l10n, diff.kind),
                        local: _pageLabel(l10n, locale, diff.localPageId),
                        remote: _pageLabel(l10n, locale, diff.remotePageId),
                      ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: !verified
                    ? () {
                        Navigator.pop(context);
                        AuthWelcomeScreen.open(context);
                      }
                    : (_syncing || _loading ? null : _syncNow),
                child: Text(
                  !verified
                      ? l10n.profileSignInCta
                      : (_syncing ? l10n.profileSyncing : l10n.profileSyncNow),
                  style: const TextStyle(fontFamily: kFontUi),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLine(AppLocalizations l10n) {
    final at = _sync?.lastSyncedAt;
    if (at == null) return l10n.profileNeverSynced;
    final relative = relativeOpenedLabel(at, DateTime.now(), l10n);
    return l10n.profileLastSynced(relative);
  }

  String _kindLabel(AppLocalizations l10n, ReadingDiffKind kind) {
    switch (kind) {
      case ReadingDiffKind.localOnly:
        return l10n.homeSyncLocalOnly;
      case ReadingDiffKind.remoteOnly:
        return l10n.homeSyncRemoteOnly;
      case ReadingDiffKind.localNewer:
        return l10n.homeSyncLocalNewer;
      case ReadingDiffKind.remoteNewer:
        return l10n.homeSyncRemoteNewer;
    }
  }

  String? _pageLabel(AppLocalizations l10n, Locale locale, int? pageId) {
    if (pageId == null) return null;
    final page = NumberFormat.decimalPattern(
      locale.toLanguageTag(),
    ).format(pageId);
    return l10n.homePageOnly(page);
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.title,
    required this.kind,
    this.local,
    this.remote,
  });

  final String title;
  final String kind;
  final String? local;
  final String? remote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final lines = <String>[
      if (local != null) '${l10n.homeSyncThisDevice}: $local',
      if (remote != null) '${l10n.homeSyncAccount}: $remote',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: kFontAmiri,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kind,
            style: TextStyle(
              fontFamily: kFontUi,
              fontSize: 12,
              color: t.emphasis,
            ),
          ),
          for (final line in lines)
            Text(
              line,
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 13,
                color: t.muted,
              ),
            ),
        ],
      ),
    );
  }
}
