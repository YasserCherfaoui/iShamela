/// Whether the running web shell should reload for [publishedBuildId] (SPEC-030).
bool shellBuildIsStale(String runningBuildId, String? publishedBuildId) {
  if (runningBuildId.isEmpty) return false;
  final published = publishedBuildId?.trim() ?? '';
  if (published.isEmpty) return false;
  return published != runningBuildId;
}
