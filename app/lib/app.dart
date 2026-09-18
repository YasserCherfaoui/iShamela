import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_page.dart';
import 'package:ishamela/features/downloads/downloads_page.dart';
import 'package:ishamela/features/library/library_page.dart';

class IshamelaApp extends ConsumerWidget {
  const IshamelaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off catalog sync once.
    ref.watch(catalogSyncTickProvider);

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E4B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = const [
      CatalogPage(),
      LibraryPage(),
      DownloadsPage(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            label: l10n.tabCatalog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            label: l10n.tabLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.download_outlined),
            label: l10n.tabDownloads,
          ),
        ],
      ),
    );
  }
}
