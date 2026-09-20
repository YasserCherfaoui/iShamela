import 'dart:js_interop';

/// Best-effort IndexedDB retention (SPEC-021). Non-fatal if denied.
Future<void> requestPersistentStorage() async {
  try {
    final storage = _navigatorStorage;
    if (storage == null) return;
    await storage.persist().toDart;
  } catch (_) {}
}

@JS('navigator.storage')
external _StorageManager? get _navigatorStorage;

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persist();
}
