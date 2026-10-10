import 'package:ishamela/core/sync/send_beacon_web.dart'
    if (dart.library.io) 'package:ishamela/core/sync/send_beacon_stub.dart'
    as impl;

void Function() bindPageHide(void Function() onHide) => impl.bindPageHide(onHide);

bool sendBeacon(String url, String body, {String? bearer, String? deviceId}) =>
    impl.sendBeacon(url, body, bearer: bearer, deviceId: deviceId);
