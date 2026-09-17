/// Compile-time configuration (SPEC-004).
library;

/// Base URL of the published bundles dataset (trailing slash required).
/// Override for local E2E: `--dart-define=CATALOG_BASE_URL=http://127.0.0.1:8000/`
const String catalogBaseUrl = String.fromEnvironment(
  'CATALOG_BASE_URL',
  defaultValue:
      'https://huggingface.co/datasets/ishamela/bundles/resolve/main/',
);

/// Bundle schema versions the app can open (SPEC-002).
const Set<String> supportedBookSchemaVersions = {'1'};

/// Catalog schema versions the app can open (SPEC-003).
const Set<String> supportedCatalogSchemaVersions = {'1'};
