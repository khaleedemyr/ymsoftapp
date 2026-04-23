class CustomerVoiceDashboard {
  final CustomerVoiceSummary summary;
  final CustomerVoiceKpis kpis;
  final List<CustomerVoiceTrendPoint> trend;
  final List<CustomerVoicePicPerformance> picPerformance;
  final List<CustomerVoiceOutletPerformance> outletPerformance;
  final List<CustomerVoiceCaseItem> cases;
  final CustomerVoicePagination pagination;
  final List<CustomerVoiceOption> outlets;
  final List<CustomerVoiceOption> assignees;
  final Map<int, List<CustomerVoiceActivity>> activities;
  final CustomerVoiceFilters filters;
  final int perfWindowDays;

  CustomerVoiceDashboard({
    required this.summary,
    required this.kpis,
    required this.trend,
    required this.picPerformance,
    required this.outletPerformance,
    required this.cases,
    required this.pagination,
    required this.outlets,
    required this.assignees,
    required this.activities,
    required this.filters,
    required this.perfWindowDays,
  });

  factory CustomerVoiceDashboard.fromJson(Map<String, dynamic> json) {
    final casesJson = _asMap(json['cases']);
    final dynamic activitiesRaw = json['activities'];

    return CustomerVoiceDashboard(
      summary: CustomerVoiceSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      kpis: CustomerVoiceKpis.fromJson(
        json['kpis'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      trend: (json['trend'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CustomerVoiceTrendPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      picPerformance: (json['picPerformance'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CustomerVoicePicPerformance.fromJson(item as Map<String, dynamic>))
          .toList(),
      outletPerformance:
          (json['outletPerformance'] as List<dynamic>? ?? <dynamic>[])
              .map((item) => CustomerVoiceOutletPerformance.fromJson(item as Map<String, dynamic>))
              .toList(),
      cases: (casesJson['data'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CustomerVoiceCaseItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      pagination: CustomerVoicePagination.fromJson(casesJson),
      outlets: (json['outlets'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CustomerVoiceOption.fromOutletJson(item as Map<String, dynamic>))
          .toList(),
      assignees: (json['assignees'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => CustomerVoiceOption.fromAssigneeJson(item as Map<String, dynamic>))
          .toList(),
      activities: _parseActivities(activitiesRaw),
      filters: CustomerVoiceFilters.fromJson(
        json['filters'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      perfWindowDays: _asInt(json['perfWindowDays'], fallback: 30),
    );
  }
}

class CustomerVoiceSummary {
  final int totalCases;
  final int openCases;
  final int severeOpen;
  final int overdueOpen;

  CustomerVoiceSummary({
    required this.totalCases,
    required this.openCases,
    required this.severeOpen,
    required this.overdueOpen,
  });

  factory CustomerVoiceSummary.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceSummary(
      totalCases: _asInt(json['total_cases']),
      openCases: _asInt(json['open_cases']),
      severeOpen: _asInt(json['severe_open']),
      overdueOpen: _asInt(json['overdue_open']),
    );
  }
}

class CustomerVoiceKpis {
  final double? firstResponseMedianMinutes;
  final double? firstResponseAvgMinutes;
  final double? resolutionAvgMinutes;
  final double? slaCompliancePct;
  final double? repeatIssueRatePct;
  final int repeatIssueWindowDays;
  final CustomerVoiceTopOutlet? negativeTopOutlet30d;

  CustomerVoiceKpis({
    required this.firstResponseMedianMinutes,
    required this.firstResponseAvgMinutes,
    required this.resolutionAvgMinutes,
    required this.slaCompliancePct,
    required this.repeatIssueRatePct,
    required this.repeatIssueWindowDays,
    required this.negativeTopOutlet30d,
  });

  factory CustomerVoiceKpis.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceKpis(
      firstResponseMedianMinutes: _asDoubleNullable(json['first_response_median_minutes']),
      firstResponseAvgMinutes: _asDoubleNullable(json['first_response_avg_minutes']),
      resolutionAvgMinutes: _asDoubleNullable(json['resolution_avg_minutes']),
      slaCompliancePct: _asDoubleNullable(json['sla_compliance_pct']),
      repeatIssueRatePct: _asDoubleNullable(json['repeat_issue_rate_pct']),
      repeatIssueWindowDays: _asInt(json['repeat_issue_window_days'], fallback: 30),
      negativeTopOutlet30d: json['negative_top_outlet_30d'] is Map<String, dynamic>
          ? CustomerVoiceTopOutlet.fromJson(
              json['negative_top_outlet_30d'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CustomerVoiceTopOutlet {
  final int? idOutlet;
  final String namaOutlet;
  final int total;

  CustomerVoiceTopOutlet({
    required this.idOutlet,
    required this.namaOutlet,
    required this.total,
  });

  factory CustomerVoiceTopOutlet.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceTopOutlet(
      idOutlet: json['id_outlet'] == null ? null : _asInt(json['id_outlet']),
      namaOutlet: json['nama_outlet']?.toString() ?? '-',
      total: _asInt(json['total']),
    );
  }
}

class CustomerVoiceTrendPoint {
  final String date;
  final int totalCases;
  final int negativeCases;

  CustomerVoiceTrendPoint({
    required this.date,
    required this.totalCases,
    required this.negativeCases,
  });

  factory CustomerVoiceTrendPoint.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceTrendPoint(
      date: json['date']?.toString() ?? '',
      totalCases: _asInt(json['total_cases']),
      negativeCases: _asInt(json['negative_cases']),
    );
  }
}

class CustomerVoicePicPerformance {
  final int assigneeId;
  final String assigneeName;
  final int totalCases;
  final int resolvedCases;
  final int openCases;
  final double? avgFirstResponseMinutes;
  final double? slaCompliancePct;

  CustomerVoicePicPerformance({
    required this.assigneeId,
    required this.assigneeName,
    required this.totalCases,
    required this.resolvedCases,
    required this.openCases,
    required this.avgFirstResponseMinutes,
    required this.slaCompliancePct,
  });

  factory CustomerVoicePicPerformance.fromJson(Map<String, dynamic> json) {
    return CustomerVoicePicPerformance(
      assigneeId: _asInt(json['assignee_id']),
      assigneeName: json['assignee_name']?.toString() ?? '-',
      totalCases: _asInt(json['total_cases']),
      resolvedCases: _asInt(json['resolved_cases']),
      openCases: _asInt(json['open_cases']),
      avgFirstResponseMinutes: _asDoubleNullable(json['avg_first_response_minutes']),
      slaCompliancePct: _asDoubleNullable(json['sla_compliance_pct']),
    );
  }
}

class CustomerVoiceOutletPerformance {
  final int? idOutlet;
  final String outletName;
  final int totalCases;
  final int negativeCases;
  final double? negativeRatePct;
  final int resolvedCases;
  final int openCases;
  final double? slaCompliancePct;

  CustomerVoiceOutletPerformance({
    required this.idOutlet,
    required this.outletName,
    required this.totalCases,
    required this.negativeCases,
    required this.negativeRatePct,
    required this.resolvedCases,
    required this.openCases,
    required this.slaCompliancePct,
  });

  factory CustomerVoiceOutletPerformance.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceOutletPerformance(
      idOutlet: json['id_outlet'] == null ? null : _asInt(json['id_outlet']),
      outletName: json['outlet_name']?.toString() ?? '-',
      totalCases: _asInt(json['total_cases']),
      negativeCases: _asInt(json['negative_cases']),
      negativeRatePct: _asDoubleNullable(json['negative_rate_pct']),
      resolvedCases: _asInt(json['resolved_cases']),
      openCases: _asInt(json['open_cases']),
      slaCompliancePct: _asDoubleNullable(json['sla_compliance_pct']),
    );
  }
}

class CustomerVoiceCaseItem {
  final int id;
  final String sourceType;
  final String? sourceRef;
  final int? outletId;
  final String outletName;
  final String authorName;
  final String? customerContact;
  final DateTime? eventAt;
  final String severity;
  final String? summaryId;
  final String rawText;
  final double? riskScore;
  final String status;
  final int? assignedTo;
  final String? assignedToName;
  final DateTime? dueAt;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  CustomerVoiceCaseItem({
    required this.id,
    required this.sourceType,
    required this.sourceRef,
    required this.outletId,
    required this.outletName,
    required this.authorName,
    required this.customerContact,
    required this.eventAt,
    required this.severity,
    required this.summaryId,
    required this.rawText,
    required this.riskScore,
    required this.status,
    required this.assignedTo,
    required this.assignedToName,
    required this.dueAt,
    required this.resolvedAt,
    required this.createdAt,
  });

  factory CustomerVoiceCaseItem.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceCaseItem(
      id: _asInt(json['id']),
      sourceType: json['source_type']?.toString() ?? '-',
      sourceRef: json['source_ref']?.toString(),
      outletId: json['id_outlet'] == null ? null : _asInt(json['id_outlet']),
      outletName: json['nama_outlet']?.toString() ?? '-',
      authorName: json['author_name']?.toString() ?? '-',
      customerContact: json['customer_contact']?.toString(),
      eventAt: _parseDateTime(json['event_at']),
      severity: json['severity']?.toString() ?? 'neutral',
      summaryId: json['summary_id']?.toString(),
      rawText: json['raw_text']?.toString() ?? '',
      riskScore: _asDoubleNullable(json['risk_score']),
      status: json['status']?.toString() ?? 'new',
      assignedTo: json['assigned_to'] == null ? null : _asInt(json['assigned_to']),
      assignedToName: json['assigned_to_name']?.toString(),
      dueAt: _parseDateTime(json['due_at']),
      resolvedAt: _parseDateTime(json['resolved_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  String get headline {
    if (summaryId != null && summaryId!.trim().isNotEmpty) {
      return summaryId!.trim();
    }
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return 'Case #$id';
    }
    if (trimmed.length <= 96) {
      return trimmed;
    }
    return '${trimmed.substring(0, 96).trim()}...';
  }
}

class CustomerVoiceActivity {
  final int id;
  final int caseId;
  final String activityType;
  final String? fromStatus;
  final String? toStatus;
  final String? note;
  final DateTime? createdAt;
  final String? actorName;

  CustomerVoiceActivity({
    required this.id,
    required this.caseId,
    required this.activityType,
    required this.fromStatus,
    required this.toStatus,
    required this.note,
    required this.createdAt,
    required this.actorName,
  });

  factory CustomerVoiceActivity.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceActivity(
      id: _asInt(json['id']),
      caseId: _asInt(json['case_id']),
      activityType: json['activity_type']?.toString() ?? '-',
      fromStatus: json['from_status']?.toString(),
      toStatus: json['to_status']?.toString(),
      note: json['note']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
      actorName: json['actor_name']?.toString(),
    );
  }
}

class CustomerVoiceOption {
  final int? id;
  final String label;

  CustomerVoiceOption({
    required this.id,
    required this.label,
  });

  factory CustomerVoiceOption.fromOutletJson(Map<String, dynamic> json) {
    return CustomerVoiceOption(
      id: json['id_outlet'] == null ? null : _asInt(json['id_outlet']),
      label: json['nama_outlet']?.toString() ?? '-',
    );
  }

  factory CustomerVoiceOption.fromAssigneeJson(Map<String, dynamic> json) {
    return CustomerVoiceOption(
      id: json['id'] == null ? null : _asInt(json['id']),
      label: json['nama_lengkap']?.toString() ?? '-',
    );
  }
}

class CustomerVoiceFilters {
  final String? status;
  final String? severity;
  final String? sourceType;
  final int? outletId;
  final String? query;
  final bool overdueOnly;

  CustomerVoiceFilters({
    required this.status,
    required this.severity,
    required this.sourceType,
    required this.outletId,
    required this.query,
    required this.overdueOnly,
  });

  factory CustomerVoiceFilters.fromJson(Map<String, dynamic> json) {
    return CustomerVoiceFilters(
      status: json['status']?.toString(),
      severity: json['severity']?.toString(),
      sourceType: json['source_type']?.toString(),
      outletId: json['id_outlet'] == null ? null : _asInt(json['id_outlet']),
      query: json['q']?.toString(),
      overdueOnly: json['overdue_only'] == true,
    );
  }
}

class CustomerVoicePagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;
  final String? nextPageUrl;
  final String? prevPageUrl;

  CustomerVoicePagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
    required this.nextPageUrl,
    required this.prevPageUrl,
  });

  factory CustomerVoicePagination.fromJson(Map<String, dynamic> json) {
    return CustomerVoicePagination(
      currentPage: _asInt(json['current_page'], fallback: 1),
      lastPage: _asInt(json['last_page'], fallback: 1),
      perPage: _asInt(json['per_page'], fallback: 20),
      total: _asInt(json['total']),
      from: _asInt(json['from']),
      to: _asInt(json['to']),
      nextPageUrl: json['next_page_url']?.toString(),
      prevPageUrl: json['prev_page_url']?.toString(),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double? _asDoubleNullable(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  if (value is List<dynamic>) {
    return <String, dynamic>{'data': value};
  }
  return <String, dynamic>{};
}

Map<int, List<CustomerVoiceActivity>> _parseActivities(dynamic value) {
  final result = <int, List<CustomerVoiceActivity>>{};

  if (value is Map) {
    final mapped = value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
    for (final entry in mapped.entries) {
      final caseId = int.tryParse(entry.key) ?? 0;
      result[caseId] = (entry.value as List<dynamic>? ?? <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => CustomerVoiceActivity.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    }
    return result;
  }

  if (value is List<dynamic>) {
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final activity = CustomerVoiceActivity.fromJson(
        item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
      );
      result.putIfAbsent(activity.caseId, () => <CustomerVoiceActivity>[]).add(activity);
    }
  }

  return result;
}