/// Compile-time configuration (SPEC-004 / SPEC-007 / SPEC-008).
library;

/// CDN root for catalog sync (trailing slash required).
const String catalogBaseUrl = String.fromEnvironment(
  'CATALOG_BASE_URL',
  defaultValue:
      'https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/',
);

/// Pinned Shamela4 revision for on-device `pages.jsonl` installs (SPEC-008).
const String shamela4Revision = String.fromEnvironment(
  'SHAMELA4_REVISION',
  defaultValue: '07554bee488a12955dd5231d08487ae7ce767d1e',
);

/// Hub dataset id for Shamela4 pages (SPEC-008).
const String shamela4Dataset = 'AuthenticIlm/Shamela4_Full_DB';

/// Resolve-base for `pages.jsonl` GETs (pinned revision; trailing slash).
String get pagesBaseUrl {
  const override = String.fromEnvironment('PAGES_BASE_URL', defaultValue: '');
  if (override.isNotEmpty) return override;
  return 'https://huggingface.co/datasets/$shamela4Dataset/resolve/$shamela4Revision/';
}

/// App identity written to book `meta.built_by` (SPEC-008).
const String appBuiltBy = 'ishamela/0.1.0';

/// Bundle schema versions the app can open (SPEC-002 / SPEC-009).
const Set<String> supportedBookSchemaVersions = {'1', '2', '3'};

/// Catalog schema versions the app can open (SPEC-003 / SPEC-008 / SPEC-009).
const Set<String> supportedCatalogSchemaVersions = {'2', '3'};
