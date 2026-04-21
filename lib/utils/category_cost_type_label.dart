/// Label tipe Category Cost (Outlet Internal Use / Waste) — selaras dengan ERP web
/// `Create.vue` & `Home.vue` `typeLabelCategoryCost`: legacy `stock_cut` ditampilkan sebagai Usage.
String categoryCostTypeLabel(String? type) {
  if (type == null || type.isEmpty) return '-';
  final t = type.trim().toLowerCase();
  switch (t) {
    case 'internal_use':
      return 'Internal Use';
    case 'spoil':
      return 'Spoil';
    case 'waste':
      return 'Waste';
    case 'usage':
    case 'stock_cut':
      return 'Usage';
    case 'r_and_d':
      return 'R & D';
    case 'marketing':
      return 'Marketing';
    case 'non_commodity':
      return 'Non Commodity';
    case 'guest_supplies':
      return 'Guest Supplies';
    case 'wrong_maker':
      return 'Wrong Maker';
    case 'training':
      return 'Training';
    default:
      return t.replaceAll('_', ' ');
  }
}
