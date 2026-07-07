class OmniMemberInfo {
  final int id;
  final String namaLengkap;
  final String? mobilePhone;
  final String? memberId;
  final String? memberLevel;
  final bool isExclusiveMember;

  OmniMemberInfo({
    required this.id,
    required this.namaLengkap,
    this.mobilePhone,
    this.memberId,
    this.memberLevel,
    this.isExclusiveMember = false,
  });

  String get tierLabel {
    final level = memberLevel;
    if (level == null || level.isEmpty) return '';
    final s = level.replaceAll('_', ' ');
    return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
  }

  factory OmniMemberInfo.fromJson(Map<String, dynamic> json) {
    return OmniMemberInfo(
      id: (json['id'] as num).toInt(),
      namaLengkap: (json['nama_lengkap'] ?? '') as String,
      mobilePhone: json['mobile_phone'] as String?,
      memberId: json['member_id'] as String?,
      memberLevel: json['member_level'] as String?,
      isExclusiveMember: json['is_exclusive_member'] == true,
    );
  }
}

class OmniContactProfile {
  final String? maritalStatus;
  final String? maritalStatusLabel;
  final int? preferredOutletId;
  final String? preferredOutletName;
  final String? preferredArea;

  OmniContactProfile({
    this.maritalStatus,
    this.maritalStatusLabel,
    this.preferredOutletId,
    this.preferredOutletName,
    this.preferredArea,
  });

  factory OmniContactProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OmniContactProfile();
    return OmniContactProfile(
      maritalStatus: json['marital_status'] as String?,
      maritalStatusLabel: json['marital_status_label'] as String?,
      preferredOutletId: (json['preferred_outlet_id'] as num?)?.toInt(),
      preferredOutletName: json['preferred_outlet_name'] as String?,
      preferredArea: json['preferred_area'] as String?,
    );
  }
}

class OmniSelectOption {
  final String value;
  final String label;

  OmniSelectOption({required this.value, required this.label});

  factory OmniSelectOption.fromJson(Map<String, dynamic> json) {
    return OmniSelectOption(
      value: (json['value'] ?? '') as String,
      label: (json['label'] ?? json['value'] ?? '') as String,
    );
  }
}

class OmniOutletOption {
  final int id;
  final String name;
  final String? location;

  OmniOutletOption({required this.id, required this.name, this.location});

  String get subtitle {
    if (location != null && location!.trim().isNotEmpty) return location!.trim();
    return '';
  }

  factory OmniOutletOption.fromJson(Map<String, dynamic> json) {
    return OmniOutletOption(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['nama_outlet'] ?? '') as String,
      location: json['location'] as String? ?? json['lokasi'] as String?,
    );
  }
}

class OmniStoryReply {
  final String kind;
  final String? storyId;
  final String? storyUrl;
  final String label;

  OmniStoryReply({
    required this.kind,
    this.storyId,
    this.storyUrl,
    required this.label,
  });

  factory OmniStoryReply.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return OmniStoryReply(kind: 'replied_to_story', label: 'Membalas story Anda');
    }
    return OmniStoryReply(
      kind: (json['kind'] ?? 'replied_to_story') as String,
      storyId: json['story_id'] as String?,
      storyUrl: json['story_url'] as String?,
      label: (json['label'] ?? 'Membalas story Anda') as String,
    );
  }
}

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
  final OmniMemberInfo? member;
  final OmniContactProfile contactProfile;
  final String? complaintSeverity;
  final String? complaintSnippet;
  final int? feedbackCaseId;
  final bool needsVoiceEscalation;
  final String? voiceCaseUrl;

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
    this.member,
    OmniContactProfile? contactProfile,
    this.complaintSeverity,
    this.complaintSnippet,
    this.feedbackCaseId,
    this.needsVoiceEscalation = false,
    this.voiceCaseUrl,
  }) : contactProfile = contactProfile ?? OmniContactProfile();

  String get title =>
      (contactName != null && contactName!.trim().isNotEmpty)
          ? contactName!.trim()
          : displayPhone;

  factory OmniConversation.fromJson(Map<String, dynamic> json) {
    final assigneesRaw = json['assignees'];
    final teamsRaw = json['assigned_teams'];
    final activeFlow = json['active_flow'];
    final memberRaw = json['member'];

    return OmniConversation(
      id: json['id'] as int,
      channel: (json['channel'] ?? 'whatsapp') as String,
      contactName: json['contact_name'] as String?,
      displayPhone: (json['display_phone'] ?? json['external_contact_id'] ?? '') as String,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: _parseDate(json['last_message_at']) ?? _parseDate(json['last_customer_message_at']),
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
      member: memberRaw is Map ? OmniMemberInfo.fromJson(Map<String, dynamic>.from(memberRaw)) : null,
      contactProfile: OmniContactProfile.fromJson(
        json['contact_profile'] is Map ? Map<String, dynamic>.from(json['contact_profile'] as Map) : null,
      ),
      complaintSeverity: json['complaint_severity'] as String?,
      complaintSnippet: json['complaint_snippet'] as String?,
      feedbackCaseId: (json['feedback_case_id'] as num?)?.toInt(),
      needsVoiceEscalation: json['needs_voice_escalation'] == true,
      voiceCaseUrl: json['voice_case_url'] as String?,
    );
  }

  OmniConversation copyWith({
    String? complaintSeverity,
    String? complaintSnippet,
    int? feedbackCaseId,
    bool? needsVoiceEscalation,
    String? voiceCaseUrl,
  }) {
    return OmniConversation(
      id: id,
      channel: channel,
      contactName: contactName,
      displayPhone: displayPhone,
      lastMessagePreview: lastMessagePreview,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      leadStage: leadStage,
      memo: memo,
      assignees: assignees,
      assignedTeams: assignedTeams,
      automationPaused: automationPaused,
      activeFlowName: activeFlowName,
      contactAvatarUrl: contactAvatarUrl,
      channelAccountLabel: channelAccountLabel,
      member: member,
      contactProfile: contactProfile,
      complaintSeverity: complaintSeverity ?? this.complaintSeverity,
      complaintSnippet: complaintSnippet ?? this.complaintSnippet,
      feedbackCaseId: feedbackCaseId ?? this.feedbackCaseId,
      needsVoiceEscalation: needsVoiceEscalation ?? this.needsVoiceEscalation,
      voiceCaseUrl: voiceCaseUrl ?? this.voiceCaseUrl,
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
        if (contactProfile.maritalStatus != null) 'marital_status': contactProfile.maritalStatus,
        if (contactProfile.preferredOutletId != null)
          'preferred_outlet_id': contactProfile.preferredOutletId,
        if (contactProfile.preferredArea != null) 'preferred_area': contactProfile.preferredArea,
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

  String get mentionLabel {
    final bits = <String>[name];
    if (jabatan != null && jabatan!.trim().isNotEmpty) bits.add(jabatan!.trim());
    if (outlet != null && outlet!.trim().isNotEmpty) bits.add(outlet!.trim());
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
  final String? mediaMime;
  final List<OmniAssignee> mentionedUsers;
  final OmniStoryReply? storyReply;

  OmniMessage({
    required this.id,
    required this.direction,
    this.messageType,
    required this.body,
    this.sentAt,
    this.authorName,
    this.mediaUrl,
    this.mediaFilename,
    this.mediaMime,
    this.mentionedUsers = const [],
    this.storyReply,
  });

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get isInternal => direction == 'internal';

  bool get isStoryReply =>
      messageType == 'story_reply' ||
      (storyReply != null && ((storyReply!.storyUrl ?? '').isNotEmpty || (storyReply!.storyId ?? '').isNotEmpty));

  String? get storyMediaUrl {
    final u = mediaUrl;
    if (u != null && u.isNotEmpty) return u;
    return storyReply?.storyUrl;
  }

  factory OmniMessage.fromJson(Map<String, dynamic> json) {
    final mentionedRaw = json['mentioned_users'];
    final storyRaw = json['story_reply'];

    return OmniMessage(
      id: json['id'] as int,
      direction: (json['direction'] ?? '') as String,
      messageType: json['message_type'] as String?,
      body: (json['body'] ?? '') as String,
      sentAt: _parseDate(json['sent_at']),
      authorName: json['author_name'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaFilename: json['media_filename'] as String?,
      mediaMime: json['media_mime'] as String?,
      mentionedUsers: mentionedRaw is List
          ? mentionedRaw.map((e) => OmniAssignee.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [],
      storyReply: storyRaw is Map ? OmniStoryReply.fromJson(Map<String, dynamic>.from(storyRaw)) : null,
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
  final bool hasMoreOlder;
  final int? oldestMessageId;
  final bool hasMoreConversations;
  final int? oldestConversationId;

  OmniInboxPollResult({
    required this.conversations,
    this.selectedConversation,
    this.messages = const [],
    this.hasMoreOlder = false,
    this.oldestMessageId,
    this.hasMoreConversations = false,
    this.oldestConversationId,
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
      hasMoreOlder: json['has_more_older'] == true,
      oldestMessageId: (json['oldest_message_id'] as num?)?.toInt(),
      hasMoreConversations: json['has_more_conversations'] == true,
      oldestConversationId: (json['oldest_conversation_id'] as num?)?.toInt(),
    );
  }
}

class OmniConversationsMoreResult {
  final List<OmniConversation> conversations;
  final bool hasMore;
  final int? oldestConversationId;

  OmniConversationsMoreResult({
    required this.conversations,
    this.hasMore = false,
    this.oldestConversationId,
  });

  factory OmniConversationsMoreResult.fromJson(Map<String, dynamic> json) {
    return OmniConversationsMoreResult(
      conversations: (json['conversations'] as List? ?? [])
          .map((e) => OmniConversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: json['has_more'] == true,
      oldestConversationId: (json['oldest_conversation_id'] as num?)?.toInt(),
    );
  }
}

class OmniMessagesPageResult {
  final OmniConversation conversation;
  final List<OmniMessage> messages;
  final bool hasMoreOlder;
  final int? oldestMessageId;

  OmniMessagesPageResult({
    required this.conversation,
    required this.messages,
    this.hasMoreOlder = false,
    this.oldestMessageId,
  });
}

class OmniInternalNoteResult {
  final OmniMessage message;
  final List<OmniMessage> messages;
  final OmniConversation? conversation;

  OmniInternalNoteResult({
    required this.message,
    List<OmniMessage>? messages,
    this.conversation,
  }) : messages = messages ?? [message];
}

class OmniInboxBootstrap {
  final List<OmniConversation> conversations;
  final bool conversationsHasMore;
  final int? conversationsOldestId;
  final String inbox;
  final List<OmniLeadStage> leadStages;
  final List<OmniAssignee> assignableUsers;
  final List<OmniTeamRef> assignableTeams;
  final bool canSeeAllChats;
  final List<OmniMessageTemplate> messageTemplates;
  final List<OmniSelectOption> maritalStatusOptions;
  final List<OmniOutletOption> outletOptions;
  final bool aiWritingEnabled;
  final bool composerSpellcheck;
  final bool autoGrammarOnSendDefault;
  final int autoGrammarMaxChars;
  final int autoGrammarMinChars;

  OmniInboxBootstrap({
    required this.conversations,
    this.conversationsHasMore = false,
    this.conversationsOldestId,
    required this.inbox,
    required this.leadStages,
    required this.assignableUsers,
    required this.assignableTeams,
    required this.canSeeAllChats,
    this.messageTemplates = const [],
    this.maritalStatusOptions = const [],
    this.outletOptions = const [],
    this.aiWritingEnabled = true,
    this.composerSpellcheck = true,
    this.autoGrammarOnSendDefault = true,
    this.autoGrammarMaxChars = 2500,
    this.autoGrammarMinChars = 4,
  });

  OmniInboxBootstrap copyWith({
    List<OmniConversation>? conversations,
    bool? conversationsHasMore,
    int? conversationsOldestId,
    String? inbox,
  }) {
    return OmniInboxBootstrap(
      conversations: conversations ?? this.conversations,
      conversationsHasMore: conversationsHasMore ?? this.conversationsHasMore,
      conversationsOldestId: conversationsOldestId ?? this.conversationsOldestId,
      inbox: inbox ?? this.inbox,
      leadStages: leadStages,
      assignableUsers: assignableUsers,
      assignableTeams: assignableTeams,
      canSeeAllChats: canSeeAllChats,
      messageTemplates: messageTemplates,
      maritalStatusOptions: maritalStatusOptions,
      outletOptions: outletOptions,
      aiWritingEnabled: aiWritingEnabled,
      composerSpellcheck: composerSpellcheck,
      autoGrammarOnSendDefault: autoGrammarOnSendDefault,
      autoGrammarMaxChars: autoGrammarMaxChars,
      autoGrammarMinChars: autoGrammarMinChars,
    );
  }

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

    final marital = (json['marital_status_options'] as List? ?? [])
        .map((e) => OmniSelectOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final outlets = (json['outlet_options'] as List? ?? [])
        .map((e) => OmniOutletOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return OmniInboxBootstrap(
      conversations: conv,
      conversationsHasMore: json['conversations_has_more'] == true,
      conversationsOldestId: (json['conversations_oldest_id'] as num?)?.toInt(),
      inbox: (json['inbox'] ?? 'all') as String,
      leadStages: stages,
      assignableUsers: users,
      assignableTeams: teams,
      canSeeAllChats: json['can_see_all_chats'] == true,
      messageTemplates: templates,
      maritalStatusOptions: marital,
      outletOptions: outlets,
      aiWritingEnabled: json['ai_writing_enabled'] != false,
      composerSpellcheck: json['composer_spellcheck'] != false,
      autoGrammarOnSendDefault: json['auto_grammar_on_send_default'] != false,
      autoGrammarMaxChars: (json['auto_grammar_max_chars'] as num?)?.toInt() ?? 2500,
      autoGrammarMinChars: (json['auto_grammar_min_chars'] as num?)?.toInt() ?? 4,
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
