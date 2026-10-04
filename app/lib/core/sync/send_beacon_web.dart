import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document.addEventListener')
external void _docListen(JSString type, JSFunction fn);

@JS('document.visibilityState')
external JSString get _visibilityState;

@JS('navigator.sendBeacon')
external JSBoolean _sendBeacon(JSString url, JSString body);

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString url, JSObject init);

void bindPageHide(void Function() onHide) {
  _docListen(
    'visibilitychange'.toJS,
    ((JSAny? _) {
      if (_visibilityState.toDart == 'hidden') onHide();
    }).toJS,
  );
  _docListen('pagehide'.toJS, ((JSAny? _) => onHide()).toJS);
}

/// Tab close cannot wait on XHR. A bearer token needs `fetch` keepalive;
/// `navigator.sendBeacon` cannot set `Authorization`.
bool sendBeacon(String url, String body, {String? bearer}) {
  if (bearer != null && bearer.isNotEmpty) {
    final headers = JSObject();
    headers['Content-Type'] = 'application/json'.toJS;
    headers['Authorization'] = 'Bearer $bearer'.toJS;
    final init = JSObject();
    init['method'] = 'POST'.toJS;
    init['body'] = body.toJS;
    init['keepalive'] = true.toJS;
    init['headers'] = headers;
    _fetch(url.toJS, init);
    return true;
  }
  return _sendBeacon(url.toJS, body.toJS).toDart;
}
