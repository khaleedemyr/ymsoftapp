import '../services/auth_service.dart';

class VideoTutorial {
  final int id;
  final int? groupId;
  final String title;
  final String? description;
  final String? videoPath;
  final String? videoName;
  final String? videoType;
  final int? videoSize;
  final String? thumbnailPath;
  final int? duration;
  final String status;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VideoTutorialGroup? group;
  final VideoTutorialCreator? creator;

  VideoTutorial({
    required this.id,
    this.groupId,
    required this.title,
    this.description,
    this.videoPath,
    this.videoName,
    this.videoType,
    this.videoSize,
    this.thumbnailPath,
    this.duration,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.group,
    this.creator,
  });

  factory VideoTutorial.fromJson(Map<String, dynamic> json) {
    return VideoTutorial(
      id: json['id'] ?? 0,
      groupId: json['group_id'],
      title: json['title'] ?? '',
      description: json['description'],
      videoPath: json['video_path'],
      videoName: json['video_name'],
      videoType: json['video_type'],
      videoSize: json['video_size'],
      thumbnailPath: json['thumbnail_path'],
      duration: json['duration'],
      status: json['status'] ?? 'A',
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      group: json['group'] != null
          ? VideoTutorialGroup.fromJson(json['group'])
          : null,
      creator: json['creator'] != null
          ? VideoTutorialCreator.fromJson(json['creator'])
          : null,
    );
  }

  String get videoUrl {
    if (videoPath == null) return '';
    return '${AuthService.storageUrl}/storage/$videoPath';
  }

  String? get thumbnailUrl {
    if (thumbnailPath == null) return null;
    return '${AuthService.storageUrl}/storage/$thumbnailPath';
  }

  String get videoSizeFormatted {
    if (videoSize == null) return 'Unknown';
    final bytes = videoSize!;
    final units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  String get durationFormatted {
    if (duration == null) return 'Unknown';
    final totalSeconds = duration!;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get creatorName {
    return creator?.namaLengkap ?? '-';
  }
}

class VideoTutorialGroup {
  final int id;
  final String name;

  VideoTutorialGroup({
    required this.id,
    required this.name,
  });

  factory VideoTutorialGroup.fromJson(Map<String, dynamic> json) {
    return VideoTutorialGroup(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class VideoTutorialCreator {
  final int id;
  final String? namaLengkap;

  VideoTutorialCreator({
    required this.id,
    this.namaLengkap,
  });

  factory VideoTutorialCreator.fromJson(Map<String, dynamic> json) {
    return VideoTutorialCreator(
      id: json['id'] ?? 0,
      namaLengkap: json['nama_lengkap'],
    );
  }
}

