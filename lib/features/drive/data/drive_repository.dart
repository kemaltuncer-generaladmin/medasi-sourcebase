import 'package:flutter/material.dart';

import 'drive_models.dart';
import 'drive_upload_payload.dart';
import 'sourcebase_drive_api.dart';

class DriveRepository {
  const DriveRepository({this.api = const SourceBaseDriveApi()});

  final SourceBaseDriveApi api;

  Future<DriveWorkspaceData> loadWorkspace() async {
    if (!api.isConfigured) {
      return DriveWorkspaceData.empty;
    }

    try {
      final response = await api.invoke('drive_bootstrap');
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return _workspaceFromJson(data);
      }
      return DriveWorkspaceData.empty;
    } catch (_) {
      return DriveWorkspaceData.empty;
    }
  }

  Future<GcsUploadSession> createUploadSession(DriveUploadDraft draft) {
    return api.createUploadSession(draft);
  }

  Future<DriveCourse> createCourse(String title) async {
    if (!api.isConfigured) {
      return _fallbackCourse(title);
    }
    final response = await api.createCourse(title);
    final row = _dataRow(response);
    return _courseFromRow(row, const [], const []);
  }

  Future<DriveSection> createSection({
    required String courseId,
    required String title,
  }) async {
    if (!api.isConfigured) {
      return DriveSection(
        id: 'local-section-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        status: DriveItemStatus.completed,
        files: const [],
      );
    }
    final response = await api.createSection(courseId: courseId, title: title);
    return _sectionFromRow(_dataRow(response), const [], null);
  }

  Future<DriveFile> completeUpload({
    required PickedDriveFile file,
    required String objectName,
    required String courseId,
    required String sectionId,
    required String courseTitle,
    required String sectionTitle,
  }) async {
    if (api.isConfigured) {
      await api.completeUpload(
        objectName: objectName,
        courseId: courseId,
        sectionId: sectionId,
        fileName: file.name,
        contentType: file.contentType,
        sizeBytes: file.sizeBytes,
      );
    }
    return DriveFile(
      id: 'file-${DateTime.now().millisecondsSinceEpoch}',
      title: file.name,
      kind: _kindFromFileName(file.name),
      sizeLabel: _sizeLabel(file.sizeBytes),
      pageLabel: 'İşleniyor',
      updatedLabel: 'Bugün',
      courseTitle: courseTitle,
      sectionTitle: sectionTitle,
      status: DriveItemStatus.processing,
      generated: const [],
    );
  }

  Future<GeneratedOutput> createGeneratedOutput({
    required DriveFile file,
    required GeneratedKind kind,
  }) async {
    if (api.isConfigured) {
      await api.createGeneratedOutput(fileId: file.id, kind: kind);
    }
    return GeneratedOutput(
      kind: kind,
      title: _generatedTitle(kind),
      detail: _generatedDetail(kind),
      updatedLabel: 'Şimdi',
    );
  }
}

DriveWorkspaceData _workspaceFromJson(Map<String, dynamic> json) {
  final rawCourses = _list(json['courses']);
  final rawSections = _list(json['sections']);
  final rawFiles = _list(json['files']);
  final rawOutputs = _list(json['generatedOutputs']);

  if (rawCourses.isEmpty) {
    return DriveWorkspaceData.empty;
  }

  final courses = rawCourses
      .map(
        (course) => _courseFromRow(course, rawSections, rawFiles, rawOutputs),
      )
      .toList();
  final recent = courses
      .expand((course) => course.sections)
      .expand((section) => section.files)
      .take(5)
      .toList();
  final collections = recent
      .where((file) => file.generated.isNotEmpty)
      .map(
        (file) => CollectionBundle(
          file: file,
          outputs: file.generated,
          subject: file.courseTitle,
          previewKind: file.generated.first.kind,
        ),
      )
      .toList();

  return DriveWorkspaceData(
    courses: courses,
    recentFiles: recent,
    uploads: recent
        .take(3)
        .map((file) => UploadTask(file: file, status: file.status))
        .toList(),
    collections: collections,
  );
}

DriveCourse _courseFromRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> allSections,
  List<Map<String, dynamic>> allFiles, [
  List<Map<String, dynamic>> allOutputs = const [],
]) {
  final id = _text(row['id']);
  final title = _text(row['title'], fallback: 'Yeni Ders');
  final sections = allSections
      .where((section) => _text(section['course_id']) == id)
      .map((section) => _sectionFromRow(section, allFiles, title, allOutputs))
      .toList();
  return DriveCourse(
    id: id,
    title: title,
    icon: Icons.favorite_border_rounded,
    iconColor: const Color(0xFFE8323D),
    iconBackground: const Color(0xFFFFEEF1),
    status: _statusFromText(_text(row['status'], fallback: 'active')),
    sections: sections,
    updatedLabel: 'Son güncelleme bugün',
    description: _metadataText(
      row['metadata'],
      'description',
      fallback:
          '$title dersine ait tüm içerikler, bölümler halinde düzenlenmiştir.',
    ),
  );
}

DriveSection _sectionFromRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> allFiles,
  String? courseTitle, [
  List<Map<String, dynamic>> allOutputs = const [],
]) {
  final id = _text(row['id']);
  final title = _text(row['title'], fallback: 'Yeni Bölüm');
  final files = allFiles
      .where((file) => _text(file['section_id']) == id)
      .map((file) => _fileFromRow(file, courseTitle ?? '', title, allOutputs))
      .toList();
  return DriveSection(
    id: id,
    title: title,
    status: _statusFromText(_text(row['status'], fallback: 'active')),
    files: files,
  );
}

DriveFile _fileFromRow(
  Map<String, dynamic> row,
  String courseTitle,
  String sectionTitle,
  List<Map<String, dynamic>> allOutputs,
) {
  final id = _text(row['id']);
  return DriveFile(
    id: id,
    title: _text(row['title'], fallback: _text(row['original_filename'])),
    kind: _kindFromText(_text(row['file_type'])),
    sizeLabel: _sizeLabel(_int(row['size_bytes'])),
    pageLabel: _int(row['page_count']) > 0
        ? '${_int(row['page_count'])} sayfa'
        : 'İşleniyor',
    updatedLabel: 'Bugün',
    courseTitle: courseTitle,
    sectionTitle: sectionTitle,
    status: _statusFromText(
      _text(row['ai_status'], fallback: _text(row['status'])),
    ),
    generated: allOutputs
        .where((output) => _text(output['source_file_id']) == id)
        .map(_outputFromRow)
        .toList(),
  );
}

GeneratedOutput _outputFromRow(Map<String, dynamic> row) {
  final kind = _generatedKindFromText(_text(row['output_type']));
  return GeneratedOutput(
    kind: kind,
    title: _text(row['title'], fallback: _generatedTitle(kind)),
    detail: '${_int(row['item_count'])} öğe',
    updatedLabel: 'Bugün',
  );
}

Map<String, dynamic> _dataRow(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map<String, dynamic>) {
    final row = data['row'];
    if (row is Map<String, dynamic>) return row;
  }
  return const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _metadataText(Object? raw, String key, {required String fallback}) {
  if (raw is Map && raw[key] != null) {
    return _text(raw[key], fallback: fallback);
  }
  return fallback;
}

DriveCourse _fallbackCourse(String title) {
  return DriveCourse(
    id: 'local-course-${DateTime.now().millisecondsSinceEpoch}',
    title: title,
    icon: Icons.menu_book_outlined,
    iconColor: const Color(0xFF1459F5),
    iconBackground: const Color(0xFFEAF2FF),
    status: DriveItemStatus.completed,
    sections: const [],
    updatedLabel: 'Son güncelleme bugün',
    description: '$title dersine ait içerikler için yeni alan hazır.',
  );
}

DriveItemStatus _statusFromText(String status) {
  return switch (status) {
    'completed' ||
    'uploaded' ||
    'ready' ||
    'active' => DriveItemStatus.completed,
    'processing' || 'pending' => DriveItemStatus.processing,
    'uploading' => DriveItemStatus.uploading,
    'failed' || 'error' => DriveItemStatus.failed,
    'draft' => DriveItemStatus.draft,
    _ => DriveItemStatus.completed,
  };
}

DriveFileKind _kindFromText(String kind) {
  return switch (kind.toLowerCase()) {
    'pdf' => DriveFileKind.pdf,
    'ppt' || 'pptx' => DriveFileKind.pptx,
    'doc' => DriveFileKind.doc,
    'zip' => DriveFileKind.zip,
    _ => DriveFileKind.docx,
  };
}

DriveFileKind _kindFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return DriveFileKind.pdf;
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
    return DriveFileKind.pptx;
  }
  if (lower.endsWith('.doc')) return DriveFileKind.doc;
  if (lower.endsWith('.zip')) return DriveFileKind.zip;
  return DriveFileKind.docx;
}

GeneratedKind _generatedKindFromText(String kind) {
  return GeneratedKind.values.firstWhere(
    (value) => value.name == kind,
    orElse: () => GeneratedKind.summary,
  );
}

String _sizeLabel(int bytes) {
  if (bytes <= 0) return '-';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(mb >= 10 ? 1 : 1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String _generatedTitle(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 'Flashcard Seti',
    GeneratedKind.question => 'Soru Seti',
    GeneratedKind.summary => 'Özet',
    GeneratedKind.algorithm => 'Algoritma',
    GeneratedKind.comparison => 'Karşılaştırma',
    GeneratedKind.podcast => 'Podcast',
    GeneratedKind.table => 'Tablo',
    GeneratedKind.mindMap => 'Zihin Haritası',
  };
}

String _generatedDetail(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => '- kart',
    GeneratedKind.question => '- soru',
    GeneratedKind.summary => '- sayfa',
    GeneratedKind.algorithm => 'Karar akışı',
    GeneratedKind.comparison => 'Konu karşılaştırması',
    GeneratedKind.podcast => 'Sesli anlatım',
    GeneratedKind.table => '1 tablo',
    GeneratedKind.mindMap => '1 zihin haritası',
  };
}
