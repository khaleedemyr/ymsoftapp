int? jaToInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class JaHomeSchedule {
  final int id;
  final String title;
  final String? programTitle;
  final String? startLabel;
  final String? endLabel;
  final String? location;
  final String? outletName;
  final String statusLabel;
  final List<String> trainerNames;
  final String role;

  JaHomeSchedule({
    required this.id,
    required this.title,
    this.programTitle,
    this.startLabel,
    this.endLabel,
    this.location,
    this.outletName,
    required this.statusLabel,
    required this.trainerNames,
    required this.role,
  });

  factory JaHomeSchedule.fromJson(Map<String, dynamic> json) {
    final trainers = json['trainer_names'];
    return JaHomeSchedule(
      id: jaToInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      programTitle: json['program_title']?.toString(),
      startLabel: json['start_label']?.toString(),
      endLabel: json['end_label']?.toString(),
      location: json['location']?.toString(),
      outletName: json['outlet_name']?.toString(),
      statusLabel: json['status_label']?.toString() ?? '',
      trainerNames: trainers is List
          ? trainers.map((e) => e.toString()).toList()
          : const [],
      role: json['role']?.toString() ?? 'participant',
    );
  }
}

class JaScheduleCard {
  final bool checkedIn;
  final int materialsCompleted;
  final int materialsTotal;
  final int quizzesCompleted;
  final int quizzesTotal;
  final int stepsCompleted;
  final int stepsTotal;
  final int progressPercent;
  final bool isPast;
  final bool isToday;
  final bool isLive;
  final String statusLabel;
  final String actionLabel;
  final List<String> trainerNames;

  JaScheduleCard({
    required this.checkedIn,
    required this.materialsCompleted,
    required this.materialsTotal,
    required this.quizzesCompleted,
    required this.quizzesTotal,
    required this.stepsCompleted,
    required this.stepsTotal,
    required this.progressPercent,
    required this.isPast,
    required this.isToday,
    required this.isLive,
    required this.statusLabel,
    required this.actionLabel,
    required this.trainerNames,
  });

  factory JaScheduleCard.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return JaScheduleCard(
        checkedIn: false,
        materialsCompleted: 0,
        materialsTotal: 0,
        quizzesCompleted: 0,
        quizzesTotal: 0,
        stepsCompleted: 0,
        stepsTotal: 0,
        progressPercent: 0,
        isPast: false,
        isToday: false,
        isLive: false,
        statusLabel: '',
        actionLabel: '',
        trainerNames: const [],
      );
    }
    final trainers = json['trainer_names'];
    return JaScheduleCard(
      checkedIn: json['checked_in'] == true,
      materialsCompleted: jaToInt(json['materials_completed']) ?? 0,
      materialsTotal: jaToInt(json['materials_total']) ?? 0,
      quizzesCompleted: jaToInt(json['quizzes_completed']) ?? 0,
      quizzesTotal: jaToInt(json['quizzes_total']) ?? 0,
      stepsCompleted: jaToInt(json['steps_completed']) ?? 0,
      stepsTotal: jaToInt(json['steps_total']) ?? 0,
      progressPercent: jaToInt(json['progress_percent']) ?? 0,
      isPast: json['is_past'] == true,
      isToday: json['is_today'] == true,
      isLive: json['is_live'] == true,
      statusLabel: json['status_label']?.toString() ?? '',
      actionLabel: json['action_label']?.toString() ?? '',
      trainerNames: trainers is List
          ? trainers.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class JaScheduleListItem {
  final int id;
  final String title;
  final String? programTitle;
  final String? startAt;
  final String? endAt;
  final String? location;
  final String? outletName;
  final JaScheduleCard card;

  JaScheduleListItem({
    required this.id,
    required this.title,
    this.programTitle,
    this.startAt,
    this.endAt,
    this.location,
    this.outletName,
    required this.card,
  });

  factory JaScheduleListItem.fromJson(Map<String, dynamic> json) {
    final program = json['program'];
    final outlet = json['outlet'];
    return JaScheduleListItem(
      id: jaToInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      programTitle: program is Map ? program['title']?.toString() : null,
      startAt: json['start_at']?.toString(),
      endAt: json['end_at']?.toString(),
      location: json['location']?.toString(),
      outletName: outlet is Map ? outlet['nama_outlet']?.toString() : null,
      card: JaScheduleCard.fromJson(
        json['card'] is Map ? Map<String, dynamic>.from(json['card'] as Map) : null,
      ),
    );
  }
}

class JaTrainerOption {
  final int id;
  final String name;

  JaTrainerOption({required this.id, required this.name});

  factory JaTrainerOption.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return JaTrainerOption(
      id: user is Map ? jaToInt(user['id']) ?? 0 : jaToInt(json['id']) ?? 0,
      name: user is Map
          ? user['nama_lengkap']?.toString() ?? ''
          : json['nama_lengkap']?.toString() ?? '',
    );
  }
}

class JaCurriculumItem {
  final String itemType;
  final int id;
  final String title;
  final bool isRequired;
  final bool completed;
  final bool locked;
  final String? type;
  final String? filePath;
  final String? url;
  final int? passScore;
  final String? quizStatus;
  final bool timeExpired;
  final Map<String, dynamic>? attempt;
  final Map<String, dynamic>? timeLimit;

  JaCurriculumItem({
    required this.itemType,
    required this.id,
    required this.title,
    required this.isRequired,
    this.completed = false,
    this.locked = false,
    this.type,
    this.filePath,
    this.url,
    this.passScore,
    this.quizStatus,
    this.timeExpired = false,
    this.attempt,
    this.timeLimit,
  });

  factory JaCurriculumItem.fromJson(Map<String, dynamic> json) {
    return JaCurriculumItem(
      itemType: json['item_type']?.toString() ?? '',
      id: jaToInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      isRequired: json['is_required'] == true,
      completed: json['completed'] == true,
      locked: json['locked'] == true,
      type: json['type']?.toString(),
      filePath: json['file_path']?.toString(),
      url: json['url']?.toString(),
      passScore: jaToInt(json['pass_score']),
      quizStatus: json['status']?.toString(),
      timeExpired: json['time_expired'] == true,
      attempt: json['attempt'] is Map
          ? Map<String, dynamic>.from(json['attempt'] as Map)
          : null,
      timeLimit: json['time_limit'] is Map
          ? Map<String, dynamic>.from(json['time_limit'] as Map)
          : null,
    );
  }

  bool get isMaterial => itemType == 'material';
  bool get isQuiz => itemType == 'quiz';
}

class JaQuizQuestion {
  final int id;
  final String question;
  final String type;
  final List<JaQuizOption> options;

  JaQuizQuestion({
    required this.id,
    required this.question,
    required this.type,
    required this.options,
  });

  factory JaQuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = json['options'];
    return JaQuizQuestion(
      id: jaToInt(json['id']) ?? 0,
      question: json['question']?.toString() ?? '',
      type: json['type']?.toString() ?? 'single',
      options: opts is List
          ? opts
              .map((e) => JaQuizOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

class JaQuizOption {
  final int id;
  final String text;

  JaQuizOption({required this.id, required this.text});

  factory JaQuizOption.fromJson(Map<String, dynamic> json) {
    return JaQuizOption(
      id: jaToInt(json['id']) ?? 0,
      text: json['option_text']?.toString() ?? '',
    );
  }
}
