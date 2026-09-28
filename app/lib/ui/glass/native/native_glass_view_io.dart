import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const bool nativeGlassViewSupported = !kIsWeb;

Widget buildNativeGlassView({
  required Map<String, Object?> creationParams,
}) {
  if (kIsWeb) return const SizedBox.shrink();
  const viewType = 'ishamela/glass_view';
  if (Platform.isIOS) {
    return UiKitView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
  if (Platform.isMacOS) {
    return AppKitView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
  return const SizedBox.shrink();
}
