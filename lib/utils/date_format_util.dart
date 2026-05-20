import 'package:intl/intl.dart';

/// Parse tanggal dari API/DB (ISO, datetime MySQL, dll). Mengembalikan null jika tidak valid.
DateTime? tryParseApiDate(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.startsWith('0000-00-00')) {
    return null;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) return parsed;

  const patterns = ['dd/MM/yyyy', 'dd-MM-yyyy', 'yyyy/MM/dd'];
  for (final pattern in patterns) {
    try {
      return DateFormat(pattern).parseStrict(trimmed);
    } catch (_) {}
  }
  return null;
}

String formatApiDate(String? value, {String pattern = 'dd MMM yyyy', String fallback = '-'}) {
  final dt = tryParseApiDate(value);
  if (dt == null) {
    final trimmed = value?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : fallback;
  }
  return DateFormat(pattern).format(dt);
}
