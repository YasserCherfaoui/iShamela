import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/web/shell_freshness.dart';

@JS('document.addEventListener')
external void _docListen(JSString type, JSFunction fn);

@JS('document.visibilityState')
external JSString get _visibilityState;

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, JSObject init);

@JS('sessionStorage.getItem')
external JSString? _sessionGet(JSString key);

@JS('sessionStorage.setItem')
external void _sessionSet(JSString key, JSString value);

@JS('location.reload')
external void _reload();

const _reloadKey = 'ishamela-shell-reloaded';

/// One check now, and another each time the tab becomes visible (SPEC-030).
void startShellFreshnessWatch() {
  unawaited(_check());
  _docListen(
    'visibilitychange'.toJS,
    ((JSAny? _) {
      if (_visibilityState.toDart == 'visible') _check();
    }).toJS,
  );
}

Future<void> _check() async {
  if (appBuildId.isEmpty) return;
  final published = await _publishedBuildId();
  if (!shellBuildIsStale(appBuildId, published) || published == null) return;
  try {
    if (_sessionGet(_reloadKey.toJS)?.toDart == published) return;
    _sessionSet(_reloadKey.toJS, published.toJS);
  } catch (_) {
    return;
  }
  _reload();
}

Future<String?> _publishedBuildId() async {
  try {
    final init = JSObject();
    init['cache'] = 'no-store'.toJS;
    final response = await _fetch('shell-version.json'.toJS, init).toDart;
    if (response.status != 200) return null;
    final text = (await response.text().toDart).toDart;
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    final id = decoded['build_id'];
    if (id is! String) return null;
    return id;
  } catch (_) {
    return null;
  }
}

extension type _Response(JSObject _) implements JSObject {
  external num get status;
  external JSPromise<JSString> text();
}
