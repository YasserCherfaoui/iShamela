/// Conditional sqlite bindings (FFI native vs WASM web).
library;

export 'sqlite_api_io.dart' if (dart.library.html) 'sqlite_api_web.dart';
