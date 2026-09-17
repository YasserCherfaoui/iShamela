class CatalogManifest {
  CatalogManifest({
    required this.catalogVersion,
    required this.generatedAt,
    required this.schemaVersion,
    required this.normVersion,
    required this.catalogSqliteZstPath,
    required this.catalogSqliteZstBytes,
    required this.catalogSqliteZstSha256,
    required this.booksBaseUrl,
    required this.bookCount,
    required this.minAppVersion,
  });

  final int catalogVersion;
  final String generatedAt;
  final int schemaVersion;
  final String normVersion;
  final String catalogSqliteZstPath;
  final int catalogSqliteZstBytes;
  final String catalogSqliteZstSha256;
  final String booksBaseUrl;
  final int bookCount;
  final String minAppVersion;

  factory CatalogManifest.fromJson(Map<String, dynamic> json) {
    final zst = json['catalog_sqlite_zst'] as Map<String, dynamic>;
    return CatalogManifest(
      catalogVersion: json['catalog_version'] as int,
      generatedAt: json['generated_at'] as String,
      schemaVersion: json['schema_version'] as int,
      normVersion: json['norm_version'] as String,
      catalogSqliteZstPath: zst['path'] as String,
      catalogSqliteZstBytes: zst['bytes'] as int,
      catalogSqliteZstSha256: zst['sha256'] as String,
      booksBaseUrl: json['books_base_url'] as String,
      bookCount: json['book_count'] as int,
      minAppVersion: json['min_app_version'] as String,
    );
  }
}

class Category {
  Category({required this.id, required this.name, required this.position});
  final int id;
  final String name;
  final int position;
}

class Author {
  Author({required this.id, required this.name, this.deathYearHijri});
  final int id;
  final String name;
  final int? deathYearHijri;
}

class Book {
  Book({
    required this.bookId,
    required this.title,
    required this.categoryId,
    required this.pageCount,
    required this.isbBytes,
    required this.sqliteBytes,
    required this.sha256,
    required this.filename,
    this.authorId,
    this.authorName,
    this.categoryName,
    this.volumeCount,
  });

  final int bookId;
  final String title;
  final int? authorId;
  final String? authorName;
  final int categoryId;
  final String? categoryName;
  final int pageCount;
  final int? volumeCount;
  final int isbBytes;
  final int sqliteBytes;
  final String sha256;
  final String filename;
}

enum DownloadStatus {
  queued,
  downloading,
  verifying,
  installing,
  done,
  error,
  paused;

  static DownloadStatus parse(String raw) =>
      DownloadStatus.values.firstWhere((e) => e.name == raw);
}

class DownloadTask {
  DownloadTask({
    required this.bookId,
    required this.status,
    required this.bytesDone,
    required this.updatedAt,
    this.bytesTotal,
    this.error,
  });

  final int bookId;
  final DownloadStatus status;
  final int bytesDone;
  final int? bytesTotal;
  final String? error;
  final int updatedAt;
}
