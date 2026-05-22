class OmniConversation {
  final int id;
  final String channel;
  final String? contactName;
  final String displayPhone;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String leadStage;
  final String? memo;
  final List<OmniAssignee> assignees;
  final List<OmniTeamRef> assignedTeams;
  final bool automationPaused;
  final String? activeFlowName;
  final String? contactAvatarUrl;
  final String? channelAccountLabel;

  OmniConversation({
    required this.id,
    this.channel = 'whatsapp',
    this.contactName,
    required this.displayPhone,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.leadStage = 'new_lead',
    this.memo,
    this.assignees = const [],
    this.assignedTeams = const [],
    this.automationPaused = false,
    this.activeFlowName,
    this.contactAvatarUrl,
    this.channelAccountLabel,
  });

  String get title =>
      (contactName != null && contactName!.trim().isNotEmpty)
          ? contactName!.trim()
          : displayPhone;

  factory OmniConversation.fromJson(Map<String, dynamic> json) {
    final assigneesRaw = json['assignees'];
    final teamsRaw = json['assigned_teams'];
    final activeFlow = json['active_flow'];

    return OmniConversation(
      id: json['id'] as int,
      channel: (json['channel'] ?? 'whatsapp') as String,
      contactName: json['contact_name'] as String?,
      displayPhone: (json['display_phone'] ?? json['external_contact_id'] ?? '') as String,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      leadStage: (json['lead_stage'] ?? 'new_lead') as String,
      memo: json['memo'] as String?,
      assignees: assigneesRaw is List
          ? assigneesRaw.map((e) => OmniAssignee.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [],
      assignedTeams: teamsRaw is List
          ? teamsRaw.map((e) => OmniTeamRef.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [],
      automationPaused: json['automation_paused'] == true,
      activeFlowName: activeFlow is Map ? activeFlow['flow_name'] as String? : null,
      contactAvatarUrl: json['contact_avatar_url'] as String?,
      channelAccountLabel: json['channel_account_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contact_name': contactName,
        'lead_stage': leadStage,
        'memo': memo,
        'assigned_user_ids': assignees.map((a) => a.id).toList(),
        'assigned_team_ids': assignedTeams.map((t) => t.id).toList(),
        'automation_paused': automationPaused,
      };
}

class OmniAssignee {
  final int id;
  final String name;
  final String? jabatan;
  final String? outlet;

  OmniAssignee({required this.id, required this.name, this.jabatan, this.outlet});

  String get subtitle {
    final bits = <String>[
      if (jabatan != null && jabatan!.trim().isNotEmpty) jabatan!.trim(),
      if (outlet != null && outlet!.trim().isNotEmpty) outlet!.trim(),
    ];
    return bits.join(' · ');
  }

  factory OmniAssignee.fromJson(Map<String, dynamic> json) {
    return OmniAssignee(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['nama_lengkap'] ?? '') as String,
      jabatan: json['jabatan'] as String?,
      outlet: json['outlet'] as String?,
    );
  }
}

class OmniMessageTemplate {
  final int id;
  final String title;
  final String? shortcut;
  final String body;

  OmniMessageTemplate({
    required this.id,
    required this.title,
    this.shortcut,
    required this.body,
  });

  factory OmniMessageTemplate.fromJson(Map<String, dynamic> json) {
    return OmniMessageTemplate(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      shortcut: json['shortcut'] as String?,
      body: (json['body'] ?? '') as String,
    );
  }
}

class OmniTeamRef {
  final int id;
  final String name;

  OmniTeamRef({required this.id, required this.name});

  factory OmniTeamRef.fromJson(Map<String, dynamic> json) {
    return OmniTeamRef(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '') as String,
    );
  }
}

class OmniMessage {
  final int id;
  final String direction;
  final String? messageType;
  final String body;
  final DateTime? sentAt;
  final String? authorName;
  final String? mediaUrl;
  final String? mediaFilename;

  OmniMessage({
    required this.id,
    required this.direction,
    this.messageType,
    required this.body,
    this.sentAt,
    this.authorName,
    this.mediaUrl,
    this.mediaFilename,
  });

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get isInternal => direction == 'internal';

  factory OmniMessage.fromJson(Map<String, dynamic> json) {
    return OmniMessage(
      id: json['id'] as int,
      direction: (json['direction'] ?? '') as String,
      messageType: json['message_type'] as String?,
      body: (json['body'] ?? '') as String,
      sentAt: _parseDate(json['sent_at']),
      authorName: json['author_name'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaFilename: json['media_filename'] as String?,
    );
  }
}

class OmniLeadStage {
  final String value;
  final String label;
  final String? color;

  OmniLeadStage({required this.value, required this.label, this.color});

  factory OmniLeadStage.fromJson(Map<String, dynamic> json) {
    return OmniLeadStage(
      value: (json['value'] ?? '') as String,
      label: (json['label'] ?? json['value'] ?? '') as String,
      color: json['color'] as String?,
    );
  }
}

/// Hasil poll ringan (daftar + pesan chat terbuka) — sama endpoint web `/poll`.
class OmniInboxPollResult {
  final List<OmniConversation> conversations;
  final OmniConversation? selectedConversation;
  final List<OmniMessage> messages;

  OmniInboxPollResult({
    required this.conversations,
    this.selectedConversation,
    this.messages = const [],
  });

  factory OmniInboxPollResult.fromJson(Map<String, dynamic> json) {
    return OmniInboxPollResult(
      conversations: (json['conversations'] as List? ?? [])
          .map((e) => OmniConversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      selectedConversation: json['selected_conversation'] != null
          ? OmniConversation.fromJson(
              Map<String, dynamic>.from(json['selected_conversation'] as Map),
            )
          : null,
      messages: (json['messages'] as List? ?? [])
          .map((e) => OmniMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class OmniInboxBootstrap {
  final List<OmniConversation> conversations;
  final String inbox;
  final List<OmniLeadStage> leadStages;
  final List<OmniAssignee> assignableUsers;
  final List<OmniTeamRef> assignableTeams;
  final bool canSeeAllChats;
  final List<OmniMessageTemplate> messageTemplates;

  OmniInboxBootstrap({
    required this.conversations,
    required this.inbox,
    required this.leadStages,
    required this.assignableUsers,
    required this.assignableTeams,
    required this.canSeeAllChats,
    this.messageTemplates = const [],
  });

  factory OmniInboxBootstrap.fromJson(Map<String, dynamic> json) {
    final conv = (json['conversations'] as List? ?? [])
        .map((e) => OmniConversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final stages = (json['lead_stages'] as List? ?? [])
        .map((e) => OmniLeadStage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final users = (json['assignable_users'] as List? ?? [])
        .map((e) => OmniAssignee.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final teams = (json['assignable_teams'] as List? ?? [])
        .map((e) => OmniTeamRef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final templates = (json['message_templates'] as List? ?? [])
        .map((e) => OmniMessageTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return OmniInboxBootstrap(
      conversations: conv,
      inbox: (json['inbox'] ?? 'all') as String,
      leadStages: stages,
      assignableUsers: users,
      assignableTeams: teams,
      canSeeAllChats: json['can_see_all_chats'] == true,
      messageTemplates: templates,
    );
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return null;
  }
}
