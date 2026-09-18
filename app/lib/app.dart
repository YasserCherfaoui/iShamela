import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_page.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/download_tabs.dart';
import 'package:ishamela/features/downloads/downloads_page.dart';
import 'package:ishamela/features/library/library_page.dart';
import 'package:ishamela/features/settings/settings_page.dart';
import 'package:ishamela/ui/app_bottom_nav.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

class IshamelaApp extends ConsumerWidget {
  const IshamelaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off catalog sync once.
    ref.watch(catalogSyncTickProvider);
    final atmosphere = ref.watch(readingAtmosphereProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildIshamelaTheme(atmosphere),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  DownloadService? _svc;

  void _onDownloadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc?.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  void _bindDownloadService(DownloadService svc) {
    if (_svc == svc) return;
    _svc?.removeListener(_onDownloadsChanged);
    _svc = svc;
    _svc!.addListener(_onDownloadsChanged);
  }

  int _activeDownloadCount() {
    final svc = _svc;
    if (svc == null) return 0;
    return filterDownloadTasks(svc.listTasks(), DownloadsTab.active).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final index = ref.watch(homeTabIndexProvider);
    final pages = const [
      CatalogPage(),
      LibraryPage(),
      DownloadsPage(),
      SettingsPage(),
    ];

    ref.listen(downloadServiceProvider, (prev, next) {
      next.whenData(_bindDownloadService);
    });
    final downloadsAsync = ref.watch(downloadServiceProvider);
    downloadsAsync.whenData(_bindDownloadService);

    final activeCount = _activeDownloadCount();
    final destinations = [
      AppBottomNavDestination(
        icon: Icons.menu_book_outlined,
        label: l10n.tabCatalog,
      ),
      AppBottomNavDestination(
        icon: Icons.library_books_outlined,
        label: l10n.tabLibrary,
      ),
      AppBottomNavDestination(
        icon: Icons.download_outlined,
        label: l10n.tabDownloads,
        badgeCount: activeCount > 0 ? activeCount : null,
      ),
      AppBottomNavDestination(
        icon: Icons.settings_outlined,
        label: l10n.tabSettings,
      ),
    ];

    final body = pages[index];

    void select(int i) => ref.read(homeTabIndexProvider.notifier).go(i);

    if (wide) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: _railIcon(d),
                      selectedIcon: _railIcon(d, selected: true),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: body,
        bottomNavigationBar: AppBottomNav(
          destinations: destinations,
          selectedIndex: index,
          onDestinationSelected: select,
        ),
      ),
    );
  }
  Widget _railIcon(AppBottomNavDestination d, {bool selected = false}) {
    final count = d.badgeCount ?? 0;
    Widget icon = Icon(d.icon);
    if (selected) {
      final t = Theme.of(context).colorScheme;
      icon = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: t.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(d.icon, color: t.onPrimaryContainer),
      );
    }
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}
