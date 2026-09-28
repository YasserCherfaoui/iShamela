import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_page.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/download_snack_host.dart';
import 'package:ishamela/features/downloads/download_tabs.dart';
import 'package:ishamela/features/home/home_page.dart';
import 'package:ishamela/features/library/library_page.dart';
import 'package:ishamela/features/library/library_sync_host.dart';
import 'package:ishamela/features/settings/settings_page.dart';
import 'package:ishamela/features/splash/startup_splash.dart';
import 'package:ishamela/ui/app_bottom_nav.dart';
import 'package:ishamela/ui/glass/chrome/glass_tab_bar.dart';
import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_runtime.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/glass/interface_style.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

class IshamelaApp extends ConsumerWidget {
  const IshamelaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off catalog sync once.
    ref.watch(catalogSyncTickProvider);
    final atmosphere = ref.watch(readingAtmosphereProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildIshamelaTheme(atmosphere),
      // SP-06: catalog sync is background; splash only awaits local DB.
      builder: (context, child) {
        return GlassRuntime(
          child: StartupSplashGate(
            child: DownloadSnackHost(
              child: LibrarySyncHost(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
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

  void _select(int i) {
    final current = ref.read(homeTabIndexProvider);
    if (i == current && i == HomeTabs.home) {
      ref.read(homeScrollToTopTickProvider.notifier).bump();
      return;
    }
    ref.read(homeTabIndexProvider.notifier).go(i);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final glass =
        ref.watch(interfaceStyleProvider) == InterfaceStyle.liquidGlass;
    final glassTokens = glass
        ? GlassTokens.forAtmosphere(ref.watch(readingAtmosphereProvider))
        : null;
    final index = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(appLocaleProvider);
    final textDir = locale.languageCode == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;
    // SPEC-023: Home · Library · Catalog · Settings
    final pages = const [
      HomePage(),
      LibraryPage(),
      CatalogPage(),
      SettingsPage(),
    ];

    ref.listen(downloadServiceProvider, (prev, next) {
      next.whenData(_bindDownloadService);
    });
    final downloadsAsync = ref.watch(downloadServiceProvider);
    downloadsAsync.whenData(_bindDownloadService);

    final activeCount = _activeDownloadCount();
    final destinations = [
      AppBottomNavDestination(icon: Icons.home_outlined, label: l10n.tabHome),
      AppBottomNavDestination(
        icon: Icons.library_books_outlined,
        label: l10n.tabLibrary,
        badgeCount: activeCount > 0 ? activeCount : null,
      ),
      AppBottomNavDestination(
        icon: Icons.menu_book_outlined,
        label: l10n.tabCatalog,
      ),
      AppBottomNavDestination(
        icon: Icons.settings_outlined,
        label: l10n.tabSettings,
      ),
    ];

    final body = pages[index];

    if (wide) {
      final rail = NavigationRail(
        selectedIndex: index,
        onDestinationSelected: _select,
        labelType: NavigationRailLabelType.all,
        backgroundColor: glass ? const Color(0x00000000) : null,
        indicatorColor: glass ? const Color(0x00000000) : null,
        selectedIconTheme: glassTokens == null
            ? null
            : IconThemeData(color: glassTokens.foregroundAccent),
        unselectedIconTheme: glassTokens == null
            ? null
            : IconThemeData(color: glassTokens.foregroundInk),
        selectedLabelTextStyle: glassTokens == null
            ? null
            : TextStyle(
                fontWeight: FontWeight.w700,
                color: glassTokens.foregroundAccent,
              ),
        unselectedLabelTextStyle: glassTokens == null
            ? null
            : TextStyle(
                fontWeight: FontWeight.w500,
                color: glassTokens.foregroundInk.withValues(alpha: 0.72),
              ),
        destinations: [
          for (final d in destinations)
            NavigationRailDestination(
              icon: _railIcon(d, tokens: glassTokens),
              selectedIcon: _railIcon(d, selected: true, tokens: glassTokens),
              label: Text(d.label),
            ),
        ],
      );
      return Directionality(
        textDirection: textDir,
        child: Scaffold(
          body: Row(
            children: [
              if (glass)
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      MediaQuery.viewPaddingOf(context).top + 8,
                      8,
                      16,
                    ),
                    child: GlassSurface(
                      shape: const GlassShape.pill(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              _GlassRailDestination(
                                destination: destinations[i],
                                selected: i == index,
                                tokens: glassTokens!,
                                onTap: () => _select(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                rail,
                const VerticalDivider(width: 1),
              ],
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
      textDirection: textDir,
      child: Scaffold(
        extendBody: glass,
        body: glass
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(context).copyWith(
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 86,
                  ),
                ),
                child: body,
              )
            : body,
        bottomNavigationBar: glass
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 22,
                ),
                child: GlassTabBar(
                  destinations: destinations,
                  selectedIndex: index,
                  onDestinationSelected: _select,
                ),
              )
            : AppBottomNav(
                destinations: destinations,
                selectedIndex: index,
                onDestinationSelected: _select,
              ),
      ),
    );
  }

  Widget _railIcon(
    AppBottomNavDestination d, {
    bool selected = false,
    GlassTokens? tokens,
  }) {
    final count = d.badgeCount ?? 0;
    Widget icon = Icon(d.icon);
    if (selected) {
      final t = Theme.of(context).colorScheme;
      icon = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens?.activeCapsule ?? t.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          d.icon,
          color: tokens?.foregroundAccent ?? t.onPrimaryContainer,
        ),
      );
    }
    if (count <= 0) return icon;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
  }
}

class _GlassRailDestination extends StatelessWidget {
  const _GlassRailDestination({
    required this.destination,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final GlassTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? tokens.foregroundAccent
        : tokens.foregroundInk.withValues(alpha: 0.72);
    final count = destination.badgeCount ?? 0;
    Widget icon = Icon(destination.icon, color: color, size: 22);
    if (selected) {
      icon = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.activeCapsule,
          borderRadius: BorderRadius.circular(999),
        ),
        child: icon,
      );
    }
    if (count > 0) {
      icon = Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
