// Mirrors web `CapaFormPanel.vue` `ensureShape` / `deepMerge`.

Map<String, dynamic> deepMerge(Map<String, dynamic> target, Map<String, dynamic> src) {
  final out = Map<String, dynamic>.from(target);
  for (final k in src.keys) {
    final v = src[k];
    final existing = out[k];
    if (v is List || existing is List) {
      out[k] = v;
    } else if (v is Map && existing is Map) {
      out[k] = deepMerge(
        existing.map((k2, v2) => MapEntry(k2.toString(), v2)),
        Map<String, dynamic>.from(v as Map),
      );
    } else {
      out[k] = v;
    }
  }
  return out;
}

Map<String, dynamic> ensureCapaShape([Map<String, dynamic>? src]) {
  final base = <String, dynamic>{
    'a': <String, dynamic>{
      'complaint_date': null,
      'complaint_time': null,
      'guest_name': null,
      'channel': null,
      'channel_other': null,
      'reported_by': null,
      'reported_by_position': null,
    },
    'b': <String, dynamic>{
      'types': <dynamic>[],
      'types_other': null,
      'description': null,
      'area_section': null,
      'involved_parties': null,
      'witnesses': null,
      'involved_party_user_ids': <dynamic>[],
      'witness_user_ids': <dynamic>[],
    },
    'c': <String, dynamic>{
      'actions': <dynamic>[],
      'actions_other': null,
      'response_time_note': null,
      'pic_user_id': null,
    },
    'e': <String, dynamic>{
      'action': null,
      'pic_user_id': null,
      'deadline': null,
      'status': 'open',
    },
    'f': <String, dynamic>{
      'action': null,
      'improvement_areas': <dynamic>[],
      'pic_user_id': null,
      'timeline': null,
      'kpi': null,
    },
    'evidence': <dynamic>[],
  };
  return deepMerge(base, src ?? {});
}

Map<String, dynamic> emptyCapaApprovalSummary() {
  return {
    'state': 'none',
    'flows': <dynamic>[],
    'next_approver_id': null,
    'can_submit': true,
    'can_resubmit': false,
  };
}

List<int> capaUserIdList(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .map((e) => int.tryParse('$e') ?? 0)
      .where((id) => id > 0)
      .toList();
}

Map<String, dynamic>? asStringKeyedMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return null;
}

List<String> verifierPendingDivisionsForUser(Map<String, dynamic> caseRow, int userId) {
  if (userId <= 0) return [];

  const divisions = ['service', 'kitchen', 'bar'];
  final result = <String>[];

  for (final div in divisions) {
    Map<String, dynamic>? capa;
    final divs = asStringKeyedMap(caseRow['capa_divisions']);
    if (divs != null && divs[div] is Map) {
      capa = asStringKeyedMap(divs[div]);
    } else if ((caseRow['capa_active_division']?.toString().toLowerCase() ?? 'service') ==
            div &&
        caseRow['capa'] is Map) {
      capa = asStringKeyedMap(caseRow['capa']);
    }
    if (capa == null) continue;

    final gRaw = capa['g'];
    final g = gRaw is Map ? asStringKeyedMap(gRaw) ?? {} : <String, dynamic>{};
    final verifierId = int.tryParse('${g['verified_by_user_id'] ?? 0}') ?? 0;
    final resultStr = g['result']?.toString().toLowerCase().trim() ?? '';
    final done = resultStr == 'effective' || resultStr == 'not_effective';
    if (verifierId == userId && !done) {
      result.add(div);
    }
  }
  return result;
}

String divisionLabel(String div) {
  switch (div) {
    case 'service':
      return 'Service';
    case 'kitchen':
      return 'Kitchen';
    case 'bar':
      return 'Bar';
    default:
      return div.isEmpty ? '—' : div;
  }
}
