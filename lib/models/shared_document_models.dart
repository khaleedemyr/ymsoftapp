class SharedDocumentFolder {
  final int id;
  final String name;
  final int? parentId;
  final bool isPublic;
  final bool canManage;
  final bool canEdit;

  SharedDocumentFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.isPublic = false,
    this.canManage = false,
    this.canEdit = false,
  });

  factory SharedDocumentFolder.fromJson(Map<String, dynamic> json) {
    return SharedDocumentFolder(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      parentId: json['parent_id'],
      isPublic: json['is_public'] == true,
      canManage: json['can_manage'] == true,
      canEdit: json['can_edit'] == true,
    );
  }
}

class SharedDocumentItem {
  final int id;
  final String title;
  final String filename;
  final String fileType;
  final int fileSize;
  final String? description;
  final int? folderId;
  final bool isPublic;
  final String? createdAt;
  final String? creatorName;
  final String permission;
  final bool canMove;
  final bool canDelete;
  final String? folderName;
  final String? downloadUrl;
  final String? previewUrl;

  SharedDocumentItem({
    required this.id,
    required this.title,
    required this.filename,
    required this.fileType,
    required this.fileSize,
    this.description,
    this.folderId,
    this.isPublic = false,
    this.createdAt,
    this.creatorName,
    this.permission = 'view',
    this.canMove = false,
    this.canDelete = false,
    this.folderName,
    this.downloadUrl,
    this.previewUrl,
  });

  factory SharedDocumentItem.fromJson(Map<String, dynamic> json) {
    return SharedDocumentItem(
      id: json['id'] ?? 0,
      title: json['title']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      fileType: json['file_type']?.toString().toLowerCase() ?? '',
      fileSize: json['file_size'] ?? 0,
      description: json['description']?.toString(),
      folderId: json['folder_id'],
      isPublic: json['is_public'] == true,
      createdAt: json['created_at']?.toString(),
      creatorName: json['creator_name']?.toString(),
      permission: json['permission']?.toString() ?? 'view',
      canMove: json['can_move'] == true,
      canDelete: json['can_delete'] == true,
      folderName: json['folder_name']?.toString(),
      downloadUrl: json['download_url']?.toString(),
      previewUrl: json['preview_url']?.toString(),
    );
  }

  bool get isPdf => fileType == 'pdf';
}

class SharedDocumentBreadcrumb {
  final int? id;
  final String name;

  SharedDocumentBreadcrumb({
    required this.id,
    required this.name,
  });

  factory SharedDocumentBreadcrumb.fromJson(Map<String, dynamic> json) {
    return SharedDocumentBreadcrumb(
      id: json['id'],
      name: json['name']?.toString() ?? 'Root',
    );
  }
}

class SharedDocumentFolderTreeItem {
  final int id;
  final String name;
  final int? parentId;
  final int depth;

  SharedDocumentFolderTreeItem({
    required this.id,
    required this.name,
    this.parentId,
    this.depth = 0,
  });

  factory SharedDocumentFolderTreeItem.fromJson(Map<String, dynamic> json) {
    return SharedDocumentFolderTreeItem(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      parentId: json['parent_id'],
      depth: json['depth'] ?? 0,
    );
  }
}

class SharedDocumentListResponse {
  final int? currentFolderId;
  final List<SharedDocumentFolder> folders;
  final List<SharedDocumentItem> documents;
  final List<SharedDocumentBreadcrumb> breadcrumbs;
  final List<SharedDocumentFolderTreeItem> folderTreeItems;

  SharedDocumentListResponse({
    required this.currentFolderId,
    required this.folders,
    required this.documents,
    required this.breadcrumbs,
    required this.folderTreeItems,
  });

  factory SharedDocumentListResponse.fromJson(Map<String, dynamic> json) {
    return SharedDocumentListResponse(
      currentFolderId: json['current_folder_id'],
      folders: (json['folders'] as List<dynamic>? ?? [])
          .map((e) => SharedDocumentFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      documents: (json['documents'] as List<dynamic>? ?? [])
          .map((e) => SharedDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      breadcrumbs: (json['breadcrumbs'] as List<dynamic>? ?? [])
          .map((e) =>
              SharedDocumentBreadcrumb.fromJson(e as Map<String, dynamic>))
          .toList(),
        folderTreeItems: (json['folder_tree_items'] as List<dynamic>? ?? [])
          .map((e) => SharedDocumentFolderTreeItem.fromJson(
            e as Map<String, dynamic>))
          .toList(),
    );
  }
}
