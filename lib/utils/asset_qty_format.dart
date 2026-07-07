import 'package:intl/intl.dart';

String formatAssetQty(dynamic val) {
  if (val == null) return '-';
  final n = double.tryParse(val.toString());
  if (n == null) return val.toString();
  return NumberFormat('#,##0.##', 'id_ID').format(n);
}

String formatAssetQtyWithUnit(dynamic qty, String? unitName) {
  final q = formatAssetQty(qty);
  if (q == '-') return q;
  final unit = unitName?.trim();
  if (unit == null || unit.isEmpty) return q;
  return '$q $unit';
}
