/// Qty efektif per nomor seri — selaras web `DeliveryOrder/Form.vue`
/// dan backend `InventorySerialEffectiveQty.php`.
class InventorySerialEffectiveQty {
  /// Qty fisik per serial dalam unit serial (mis. 500 Pcs per chunk SN).
  static double resolvePhysical(Map<String, dynamic> serial) {
    final repackQty = _num(serial['repack_qty']);
    final repackUnitId = serial['repack_unit_id'];
    if (repackUnitId != null && repackQty > 0) {
      return repackQty;
    }

    if (serial['source_type']?.toString() == 'repack') {
      for (final field in ['source_qty', 'generated_qty_unit']) {
        final qty = _num(serial[field]);
        if (qty > 0) return qty;
      }
    }

    return 1.0;
  }

  static double convertQtyBetweenItemUnits(
    double qty,
    String fromUnitName,
    String toUnitName,
    Map<String, dynamic> item,
  ) {
    final from = fromUnitName.trim().toLowerCase();
    final to = toUnitName.trim().toLowerCase();
    if (from.isEmpty || to.isEmpty || from == to) return qty;

    final units = item['units'];
    if (units is! Map) return qty;

    final smallConv = _num(item['small_conversion_qty']) <= 0 ? 1.0 : _num(item['small_conversion_qty']);
    final mediumConv = _num(item['medium_conversion_qty']) <= 0 ? 1.0 : _num(item['medium_conversion_qty']);

    double toSmall(double amount, String unitName) {
      final u = unitName.trim().toLowerCase();
      if (u == units['small_unit']?.toString().trim().toLowerCase()) return amount;
      if (u == units['medium_unit']?.toString().trim().toLowerCase()) return amount * smallConv;
      if (u == units['large_unit']?.toString().trim().toLowerCase()) return amount * smallConv * mediumConv;
      return amount;
    }

    double fromSmall(double amountSmall, String unitName) {
      final u = unitName.trim().toLowerCase();
      if (u == units['small_unit']?.toString().trim().toLowerCase()) return amountSmall;
      if (u == units['medium_unit']?.toString().trim().toLowerCase()) {
        return smallConv > 0 ? amountSmall / smallConv : 0;
      }
      if (u == units['large_unit']?.toString().trim().toLowerCase()) {
        final divider = smallConv * mediumConv;
        return divider > 0 ? amountSmall / divider : 0;
      }
      return amountSmall;
    }

    return fromSmall(toSmall(qty, from), to);
  }

  /// Qty serial dalam unit packing list.
  /// Prioritas: [effective_qty] dari API (sudah dikonversi via master item).
  static double effectiveQtyForPackingList(
    Map<String, dynamic> serial,
    String packingUnit, [
    Map<String, dynamic>? item,
  ]) {
    final apiQty = _num(serial['effective_qty']);
    if (apiQty > 0) return apiQty;

    final physical = _num(serial['physical_qty']) > 0
        ? _num(serial['physical_qty'])
        : (_num(serial['repack_qty']) > 0 ? _num(serial['repack_qty']) : resolvePhysical(serial));

    final repackUnit = serial['repack_unit_name']?.toString().trim().toLowerCase() ?? '';
    final docUnit = packingUnit.trim().toLowerCase();
    final serialUnit = serial['unit_name']?.toString().trim().toLowerCase() ?? '';

    if (item != null && serialUnit.isNotEmpty && docUnit.isNotEmpty && serialUnit != docUnit) {
      return convertQtyBetweenItemUnits(physical, serialUnit, docUnit, item);
    }

    if (serialUnit.isNotEmpty && docUnit.isNotEmpty && serialUnit == docUnit) {
      return physical;
    }
    if (repackUnit.isNotEmpty && docUnit.isNotEmpty && repackUnit == docUnit) {
      return physical;
    }

    return physical;
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString()) ?? 0;
  }
}
