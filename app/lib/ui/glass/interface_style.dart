/// Chrome style (SPEC-027 §2). Orthogonal to the reading theme.
enum InterfaceStyle {
  manuscript,
  liquidGlass;

  static const settingsKey = 'prefs.interfaceStyle';
  static const updatedAtKey = 'prefs.interfaceStyleUpdatedAt';

  static InterfaceStyle fromId(String? raw) {
    switch (raw) {
      case 'liquidGlass':
        return InterfaceStyle.liquidGlass;
      case 'manuscript':
      default:
        return InterfaceStyle.manuscript;
    }
  }

  String get id {
    switch (this) {
      case InterfaceStyle.manuscript:
        return 'manuscript';
      case InterfaceStyle.liquidGlass:
        return 'liquidGlass';
    }
  }
}
