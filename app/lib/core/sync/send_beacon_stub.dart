/// Native and test builds. Web uses [send_beacon_web.dart].
void Function() bindPageHide(void Function() onHide) => () {};

bool sendBeacon(String url, String body, {String? bearer}) => false;
