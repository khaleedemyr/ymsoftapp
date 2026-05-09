import 'package:intl/intl.dart';

String disp(dynamic v) {
  if (v == null) return '—';
  final s = v.toString().trim();
  return s.isEmpty ? '—' : s;
}

String sourceTypeLabel(String? source) {
  switch (source ?? '') {
    case 'google_review':
      return 'Google';
    case 'instagram_comment':
      return 'Instagram';
    case 'guest_comment':
      return 'Guest Comment';
    default:
      return source ?? '—';
  }
}

String followUpLabel(String? v) {
  switch (v ?? '') {
    case 'customer':
      return 'Customer';
    case 'internal':
      return 'Internal';
    default:
      return '—';
  }
}

String impactLine(dynamic raw) {
  if (raw is! List) return '—';
  const m = {
    'reputasi': 'Reputasi',
    'finansial': 'Finansial',
    'operasional': 'Operasional',
  };
  final parts = <String>[];
  for (final x in raw) {
    final k = x.toString();
    parts.add(m[k] ?? k);
  }
  return parts.isEmpty ? '—' : parts.join(', ');
}

String channelLabel(String? ch, String? other) {
  final s = ch?.toLowerCase() ?? '';
  const map = {
    'dine_in': 'Dine in',
    'online_review': 'Online review',
    'delivery': 'Delivery',
    'walk_in': 'Walk in',
    'other': 'Other',
    'google_review': 'Google Review',
    'instagram_comment': 'Instagram',
    'guest_comment': 'Guest Comment',
  };
  if (s == 'other' && (other != null && other.trim().isNotEmpty)) {
    return '${map['other']}: $other';
  }
  return map[s] ?? disp(ch);
}

const complaintTypeMap = {
  'food_quality': 'Food Quality',
  'service': 'Service',
  'cleanliness': 'Cleanliness',
  'waiting_time': 'Waiting Time',
  'billing': 'Billing',
  'other': 'Others',
};

String complaintTypeLabel(String v) {
  return complaintTypeMap[v] ?? v;
}

const immediateActionMap = {
  'apology': 'Apology diberikan',
  'replace_product': 'Replace product',
  'refund_discount': 'Refund / Discount',
  'escalate': 'Escalate ke Supervisor / Manager',
  'other': 'Lainnya',
};

String immediateActionLabel(dynamic v) =>
    immediateActionMap[v.toString()] ?? v.toString();

const improvementMap = {
  'sop': 'SOP',
  'training': 'Training',
  'equipment': 'Equipment',
  'manpower': 'Manpower',
  'system': 'System',
};

String improvementAreaLabel(dynamic v) => improvementMap[v.toString()] ?? v.toString();

const contactMethodMap = {
  'call': 'Call',
  'whatsapp': 'WhatsApp',
  'email': 'Email',
};

String verificationResultLabel(String? r) {
  switch (r?.toLowerCase().trim() ?? '') {
    case 'effective':
      return 'Effective — efektif';
    case 'not_effective':
      return 'Not effective — tidak efektif';
    default:
      return '— belum —';
  }
}

String contactedLabel(String? v) {
  switch (v?.toLowerCase() ?? '') {
    case 'yes':
      return 'Ya';
    case 'no':
      return 'Tidak';
    default:
      return '—';
  }
}

String satisfactionLabel(String? v) {
  switch (v?.toLowerCase() ?? '') {
    case 'satisfied':
      return 'Satisfied — puas';
    case 'neutral':
      return 'Neutral — netral';
    case 'unsatisfied':
      return 'Unsatisfied — tidak puas';
    default:
      return '—';
  }
}

String contactMethodsLine(dynamic arr) {
  if (arr is! List || arr.isEmpty) return '—';
  return arr.map((x) => contactMethodMap[x.toString()] ?? x.toString()).join(', ');
}

String userIdLabel(int? authUserId, dynamic id) {
  final n = int.tryParse('$id') ?? 0;
  if (n <= 0) return '—';
  if (authUserId != null && n == authUserId) return 'Anda (user #$n)';
  return 'User #$n';
}

String formatDt(dynamic v) {
  if (v == null) return '—';
  final dt = DateTime.tryParse(v.toString());
  if (dt == null) return v.toString();
  return DateFormat.yMMMMEEEEd('id_ID').add_Hm().format(dt.toLocal());
}

bool isImageEvidence(Map<String, dynamic> ev) {
  final mime = ev['mime']?.toString().toLowerCase() ?? '';
  if (mime.startsWith('image/')) return true;
  final ref =
      '${ev['url'] ?? ''}${ev['path'] ?? ''}${ev['original_name'] ?? ''}'.toLowerCase();
  return RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)(\?|$)').hasMatch(ref);
}
