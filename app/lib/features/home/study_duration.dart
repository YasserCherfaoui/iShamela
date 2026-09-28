import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Home weekly-time label. Under an hour stays a minute count.
/// 70 minutes in English is `1h10min` (SPEC-023 §2.3, display only).
String formatStudyMinutes(int totalMinutes, Locale locale) {
  final digits = NumberFormat.decimalPattern(locale.toLanguageTag());
  String d(int n) => digits.format(n);
  if (totalMinutes < 60) return d(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final mins = totalMinutes % 60;
  final h = d(hours);
  final m = d(mins);
  if (locale.languageCode == 'ar') {
    return mins == 0 ? '$hس' : '$hس$mد';
  }
  return mins == 0 ? '${h}h' : '${h}h${m}min';
}
