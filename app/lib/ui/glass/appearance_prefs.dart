import 'package:ishamela/ui/glass/interface_style.dart';

/// Appearance preference synced on `updatedAt` (SPEC-027 §2 / §8).
class AppearancePref {
  const AppearancePref({required this.style, required this.updatedAt});

  final InterfaceStyle style;
  final int updatedAt;

  static const AppearancePref defaults = AppearancePref(
    style: InterfaceStyle.manuscript,
    updatedAt: 0,
  );
}

/// Remote wins only when its timestamp is strictly newer than a local choice.
/// A missing remote leaves the local value alone. Equal timestamps keep local.
AppearancePref chooseAppearance({
  required AppearancePref local,
  required AppearancePref? remote,
}) {
  if (remote == null) return local;
  if (remote.updatedAt > local.updatedAt) return remote;
  return local;
}
