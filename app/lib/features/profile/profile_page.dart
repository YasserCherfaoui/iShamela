import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/arabic_digits.dart';
import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/user_profile.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_welcome_screen.dart';
import 'package:ishamela/features/home/home_stats_dao.dart';
import 'package:ishamela/features/library/bookmarks_page.dart';
import 'package:ishamela/features/library/history_page.dart';
import 'package:ishamela/features/library/notes_list_page.dart';
import 'package:ishamela/features/settings/storage_page.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/section_label.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-024 Profile — identity, lifetime stats, sync, account management.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _tick = 0;
  bool _syncing = false;

  Future<void> _syncNow(StateDatabase state, UserProfile profile) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _syncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileSyncing)),
    );
    try {
      await ref.read(authProvider.notifier).syncNow(state);
    } catch (_) {
      // syncNow already records lastError on StateDatabase.
    }
    if (mounted) {
      setState(() {
        _syncing = false;
        _tick++;
      });
    }
  }

  Future<void> _editDisplayName(UserProfile profile) async {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final ctrl = TextEditingController(text: profile.displayName ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.profileEditName,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(labelText: l10n.profileEditNameHint),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.profileEditNameSave),
              ),
            ],
          ),
        );
      },
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (saved != true || !mounted) return;
    if (name.isEmpty || name.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEditNameInvalid)),
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).updateDisplayName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditNameSaved)),
        );
        setState(() => _tick++);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileEditNameInvalid)),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.profileChangePassword,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: current,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l10n.profileCurrentPassword),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: next,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.profileNewPassword),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l10n.profileConfirmPassword),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      },
    );
    final cur = current.text;
    final neu = next.text;
    final conf = confirm.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok != true || !mounted) return;
    if (neu != conf || neu.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profilePasswordMismatch)),
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: cur,
            newPassword: neu,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePasswordChanged)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePasswordMismatch)),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileSignOut),
        content: Text(l10n.profileSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteAccount(StateDatabase state) async {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    var wipeLocal = false;
    final confirmCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.profileDeleteAccount,
                    style: TextStyle(
                      fontFamily: kFontAmiri,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: t.danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.profileDeleteExplain,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 13,
                      color: t.muted,
                      height: 1.45,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: wipeLocal,
                    onChanged: (v) => setSheet(() => wipeLocal = v ?? false),
                    title: Text(
                      l10n.profileDeleteWipeLocal,
                      style: TextStyle(fontFamily: kFontUi, fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  TextField(
                    controller: confirmCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.profileDeleteTypeConfirm,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (confirmCtrl.text.trim() !=
                          l10n.profileDeleteConfirmWord) {
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: Text(l10n.profileDeleteAccount),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    final typedOk =
        confirmCtrl.text.trim() == l10n.profileDeleteConfirmWord;
    confirmCtrl.dispose();
    if (confirmed != true || !typedOk || !mounted) return;

    try {
      await ref.read(authProvider.notifier).reauthenticate();
      await ref.read(authProvider.notifier).deleteAccount(wipeLocal: wipeLocal);
      if (wipeLocal) {
        state.clearReadingHistory();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteDone)),
        );
        Navigator.of(context).pop();
      }
    } on AuthUnavailable {
      // Requires recent login — password prompt already attempted via reauth.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final auth = ref.watch(authProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final width = MediaQuery.sizeOf(context).width;
    final _ = _tick;

    final body = stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (state) {
        final stats = HomeStatsDao(state).compute(now: DateTime.now());
        final sync = state.getSyncState();
        final profile = auth.profileOrNull;
        final isGuest = auth.isGuest;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (isGuest)
              _GuestCard(onSignIn: () => AuthWelcomeScreen.open(context))
            else if (profile != null)
              _IdentityCard(
                profile: profile,
                onEditName: () => _editDisplayName(profile),
              ),
            const SizedBox(height: 20),
            _LifetimeGrid(stats: stats),
            if (!isGuest && profile != null) ...[
              const SizedBox(height: 20),
              SectionLabel(label: l10n.profileSync),
              _SyncSection(
                sync: sync,
                syncing: _syncing,
                onSyncNow: () => _syncNow(state, profile),
                onCellularChanged: (v) {
                  state.setSyncState(cellularAllowed: v);
                  setState(() => _tick++);
                },
                onAutoDownloadChanged: (v) {
                  state.setSyncState(autoDownload: v);
                  setState(() => _tick++);
                },
              ),
            ],
            const SizedBox(height: 20),
            SectionLabel(label: l10n.profileShortcutSettings),
            _ShortcutsCard(
              onStorage: () => StoragePage.open(context),
              onHistory: () => HistoryPage.open(context),
              onBookmarks: () => BookmarksPage.open(context),
              onNotes: () => NotesListPage.open(context),
              onSettings: () {
                Navigator.of(context).pop();
                ref.read(homeTabIndexProvider.notifier).go(HomeTabs.settings);
              },
            ),
            if (!isGuest) ...[
              const SizedBox(height: 20),
              SectionLabel(label: l10n.profileAccount),
              _AccountCard(
                showChangePassword: profile?.hasEmailProvider == true,
                onChangePassword: _changePassword,
                onSignOut: _signOut,
                onDelete: () => _deleteAccount(state),
              ),
            ],
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.profileTitle,
          style: TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
      ),
      body: width >= 800
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: body,
              ),
            )
          : body,
    );
  }
}

String _digits(int n) => toArabicIndicDigits(n);

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: t.green100,
              child: const RosetteMark(size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.profileGuest,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileGuestCopy,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 13,
                color: t.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSignIn,
              child: Text(l10n.profileSignInCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onEditName});

  final UserProfile profile;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : (profile.email ?? profile.uid);
    final initial = name.isNotEmpty ? name[0] : '?';

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.goldSoft, width: 2),
              ),
              child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(profile.photoUrl!),
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: t.green900,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: kFontAmiri,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: t.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context).profileEditName,
                        onPressed: onEditName,
                        icon: Icon(Icons.edit_outlined, color: t.muted, size: 20),
                      ),
                    ],
                  ),
                  if (profile.email != null)
                    Text(
                      profile.email!,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontSize: 13,
                        color: t.muted,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final p in profile.providers)
                        _ProviderBadge(kind: p),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.kind});

  final AuthProviderKind kind;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final label = switch (kind) {
      AuthProviderKind.apple => '',
      AuthProviderKind.google => 'G',
      AuthProviderKind.email => '✉️',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.hairline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontUi,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: t.ink,
        ),
      ),
    );
  }
}

class _LifetimeGrid extends StatelessWidget {
  const _LifetimeGrid({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cells = [
      (stats.lifetimeBooksStarted, l10n.profileLifetimeBooks),
      (stats.lifetimePages, l10n.profileLifetimePages),
      (stats.lifetimeMinutes, l10n.profileLifetimeMinutes),
      (stats.longestStreak, l10n.profileLongestStreak),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        for (final c in cells)
          _LifetimeCell(
            value: _digits(c.$1),
            label: c.$2,
            onTap: () => HistoryPage.open(context),
          ),
      ],
    );
  }
}

class _LifetimeCell extends StatelessWidget {
  const _LifetimeCell({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.chipBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: t.emphasis,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 12,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncSection extends StatelessWidget {
  const _SyncSection({
    required this.sync,
    required this.syncing,
    required this.onSyncNow,
    required this.onCellularChanged,
    required this.onAutoDownloadChanged,
  });

  final SyncState sync;
  final bool syncing;
  final VoidCallback onSyncNow;
  final ValueChanged<bool> onCellularChanged;
  final ValueChanged<bool> onAutoDownloadChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    String status;
    if (sync.lastSyncedAt == null) {
      status = l10n.profileNeverSynced;
    } else {
      final relative = relativeOpenedLabel(
        sync.lastSyncedAt!,
        DateTime.now(),
        l10n,
      );
      status = l10n.profileLastSynced(relative);
    }

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(status),
            trailing: TextButton(
              onPressed: syncing ? null : onSyncNow,
              child: Text(l10n.profileSyncNow),
            ),
          ),
          if (sync.lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: t.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.profileSyncError,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontSize: 12,
                        color: t.gold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: syncing ? null : onSyncNow,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            title: Text(l10n.profileSyncCellular),
            value: sync.cellularAllowed,
            onChanged: onCellularChanged,
          ),
          SwitchListTile(
            title: Text(l10n.profileAutoDownload),
            value: sync.autoDownload,
            onChanged: onAutoDownloadChanged,
          ),
        ],
      ),
    );
  }
}

class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard({
    required this.onStorage,
    required this.onHistory,
    required this.onBookmarks,
    required this.onNotes,
    required this.onSettings,
  });

  final VoidCallback onStorage;
  final VoidCallback onHistory;
  final VoidCallback onBookmarks;
  final VoidCallback onNotes;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    Widget row(String label, VoidCallback onTap) => ListTile(
          title: Text(label),
          trailing: Icon(Icons.chevron_left, color: t.muted),
          onTap: onTap,
        );
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Column(
        children: [
          row(l10n.profileShortcutStorage, onStorage),
          const Divider(height: 1),
          row(l10n.profileShortcutHistory, onHistory),
          const Divider(height: 1),
          row(l10n.profileShortcutBookmarks, onBookmarks),
          const Divider(height: 1),
          row(l10n.profileShortcutNotes, onNotes),
          const Divider(height: 1),
          row(l10n.profileShortcutSettings, onSettings),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.showChangePassword,
    required this.onChangePassword,
    required this.onSignOut,
    required this.onDelete,
  });

  final bool showChangePassword;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Column(
        children: [
          if (showChangePassword) ...[
            ListTile(
              title: Text(l10n.profileChangePassword),
              trailing: Icon(Icons.chevron_left, color: t.muted),
              onTap: onChangePassword,
            ),
            const Divider(height: 1),
          ],
          ListTile(
            title: Text(l10n.profileSignOut),
            onTap: onSignOut,
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              l10n.profileDeleteAccount,
              style: TextStyle(color: t.danger, fontWeight: FontWeight.w600),
            ),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
