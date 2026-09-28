import 'package:flutter/services.dart';

/// Platform snapshot for Liquid Glass (SPEC-027 §5.2).
class GlassPlatformStatus {
  const GlassPlatformStatus({
    required this.available,
    required this.reduceTransparency,
    required this.powerSave,
  });

  final bool available;
  final bool reduceTransparency;
  final bool powerSave;

  static const unavailable = GlassPlatformStatus(
    available: false,
    reduceTransparency: false,
    powerSave: false,
  );
}

/// Method channel `ishamela/glass`.
class NativeGlassChannel {
  NativeGlassChannel({MethodChannel? channel, EventChannel? events})
      : _channel = channel ?? const MethodChannel('ishamela/glass'),
        _events = events ?? const EventChannel('ishamela/glass/events');

  static final NativeGlassChannel instance = NativeGlassChannel();

  final MethodChannel _channel;
  final EventChannel _events;

  Future<bool> isAvailable() => _bool('isAvailable');

  Future<bool> reduceTransparency() => _bool('reduceTransparency');

  Future<bool> isPowerSaveMode() => _bool('isPowerSaveMode');

  Stream<bool> reduceTransparencyChanged() {
    return _events.receiveBroadcastStream().map((event) => event == true);
  }

  Future<GlassPlatformStatus> query() async {
    try {
      final available = await isAvailable();
      final reduce = await reduceTransparency();
      final power = await isPowerSaveMode();
      return GlassPlatformStatus(
        available: available,
        reduceTransparency: reduce,
        powerSave: power,
      );
    } catch (_) {
      return GlassPlatformStatus.unavailable;
    }
  }

  Future<bool> _bool(String method) async {
    try {
      final value = await _channel.invokeMethod<bool>(method);
      return value ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
