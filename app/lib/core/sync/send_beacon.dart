import 'package:ishamela/core/sync/send_beacon_web.dart'
    if (dart.library.io) 'package:ishamela/core/sync/send_beacon_stub.dart'
    as impl;

void bindPageHide(void Function() onHide) => impl.bindPageHide(onHide);

bool sendBeacon(String url, String body, {String? bearer}) =>
    impl.sendBeacon(url, body, bearer: bearer);
