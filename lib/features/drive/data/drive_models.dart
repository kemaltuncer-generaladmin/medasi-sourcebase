import 'package:flutter/material.dart';

enum DriveFileKind { pdf, pptx, docx, doc, zip }

enum DriveItemStatus { completed, processing, uploading, failed, draft }

enum GeneratedKind {
  flashcard,
  question,
  summary,
  algorithm,
  comparison,
  podcast,
  table,
  mindMap,
}

class DriveWorkspaceData {
  const DriveWorkspaceData({
    required this.courses,
    required this.recentFiles,
    required this.uploads,
    required this.collections,
  });

  static const empty = DriveWorkspaceData(
    courses: [],
    recentFiles: [],
    uploads: [],
    collections: [],
  );

  final List<DriveCourse> courses;
  final List<DriveFile> recentFiles;
  final List<UploadTask> uploads;
  final List<CollectionBundle> collections;

  DriveCourse? get primaryCourse => courses.isEmpty ? null : courses.first;

  DriveSection? get primarySection {
    final course = primaryCourse;
    if (course == null || course.sections.isEmpty) return null;
    return course.sections.first;
  }

  DriveFile? get primaryFile {
    final section = primarySection;
    if (section == null || section.files.isEmpty) return null;
    return section.files.first;
  }

  DriveWorkspaceData copyWith({
    List<DriveCourse>? courses,
    List<DriveFile>? recentFiles,
    List<UploadTask>? uploads,
    List<CollectionBundle>? collections,
  }) {
    return DriveWorkspaceData(
      courses: courses ?? this.courses,
      recentFiles: recentFiles ?? this.recentFiles,
      uploads: uploads ?? this.uploads,
      collections: collections ?? this.collections,
    );
  }
}

class DriveCourse {
  const DriveCourse({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.status,
    required this.sections,
    required this.updatedLabel,
    required this.description,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final DriveItemStatus status;
  final List<DriveSection> sections;
  final String updatedLabel;
  final String description;

  int get fileCount =>
      sections.fold<int>(0, (total, section) => total + section.files.length);

  DriveCourse copyWith({
    String? id,
    String? title,
    IconData? icon,
    Color? iconColor,
    Color? iconBackground,
    DriveItemStatus? status,
    List<DriveSection>? sections,
    String? updatedLabel,
    String? description,
  }) {
    return DriveCourse(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      iconBackground: iconBackground ?? this.iconBackground,
      status: status ?? this.status,
      sections: sections ?? this.sections,
      updatedLabel: updatedLabel ?? this.updatedLabel,
      description: description ?? this.description,
    );
  }
}

class DriveSection {
  const DriveSection({
    required this.id,
    required this.title,
    required this.status,
    required this.files,
  });

  final String id;
  final String title;
  final DriveItemStatus status;
  final List<DriveFile> files;

  DriveSection copyWith({
    String? id,
    String? title,
    DriveItemStatus? status,
    List<DriveFile>? files,
  }) {
    return DriveSection(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      files: files ?? this.files,
    );
  }
}

class DriveFile {
  const DriveFile({
    required this.id,
    required this.title,
    required this.kind,
    required this.sizeLabel,
    required this.pageLabel,
    required this.updatedLabel,
    required this.courseTitle,
    required this.sectionTitle,
    required this.status,
    this.tag,
    this.featured = false,
    this.selected = false,
    this.generated = const [],
  });

  final String id;
  final String title;
  final DriveFileKind kind;
  final String sizeLabel;
  final String pageLabel;
  final String updatedLabel;
  final String courseTitle;
  final String sectionTitle;
  final DriveItemStatus status;
  final String? tag;
  final bool featured;
  final bool selected;
  final List<GeneratedOutput> generated;

  DriveFile copyWith({
    String? id,
    String? title,
    DriveFileKind? kind,
    String? sizeLabel,
    String? pageLabel,
    String? updatedLabel,
    String? courseTitle,
    String? sectionTitle,
    DriveItemStatus? status,
    String? tag,
    bool? featured,
    bool? selected,
    List<GeneratedOutput>? generated,
  }) {
    return DriveFile(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      pageLabel: pageLabel ?? this.pageLabel,
      updatedLabel: updatedLabel ?? this.updatedLabel,
      courseTitle: courseTitle ?? this.courseTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      featured: featured ?? this.featured,
      selected: selected ?? this.selected,
      generated: generated ?? this.generated,
    );
  }
}

class GeneratedOutput {
  const GeneratedOutput({
    required this.kind,
    required this.title,
    required this.detail,
    required this.updatedLabel,
  });

  final GeneratedKind kind;
  final String title;
  final String detail;
  final String updatedLabel;
}

class UploadTask {
  const UploadTask({
    required this.file,
    required this.status,
    this.progress = 1,
    this.errorLabel,
  });

  final DriveFile file;
  final DriveItemStatus status;
  final double progress;
  final String? errorLabel;
}

class CollectionBundle {
  const CollectionBundle({
    required this.file,
    required this.outputs,
    required this.subject,
    required this.previewKind,
  });

  final DriveFile file;
  final List<GeneratedOutput> outputs;
  final String subject;
  final GeneratedKind previewKind;
}

class DriveUploadDraft {
  const DriveUploadDraft({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.courseId,
    required this.sectionId,
  });

  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String courseId;
  final String sectionId;

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'courseId': courseId,
      'sectionId': sectionId,
    };
  }
}

class GcsUploadSession {
  const GcsUploadSession({
    required this.uploadUrl,
    required this.objectName,
    required this.bucket,
    required this.headers,
    required this.expiresAt,
  });

  factory GcsUploadSession.fromJson(Map<String, dynamic> json) {
    final headers = <String, String>{};
    final rawHeaders = json['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    return GcsUploadSession(
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      objectName: json['objectName']?.toString() ?? '',
      bucket: json['bucket']?.toString() ?? '',
      headers: headers,
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String uploadUrl;
  final String objectName;
  final String bucket;
  final Map<String, String> headers;
  final DateTime expiresAt;
}
