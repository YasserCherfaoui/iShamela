/// Native and test builds. Web uses [send_beacon_web.dart].
void bindPageHide(void Function() onHide) {}

bool sendBeacon(String url, String body, {String? bearer}) => false;
