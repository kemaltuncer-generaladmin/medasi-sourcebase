import 'package:flutter/material.dart';

import 'drive_models.dart';
import 'drive_upload_payload.dart';
import 'sourcebase_drive_api.dart';

class DriveRepository {
  const DriveRepository({this.api = const SourceBaseDriveApi()});

  final SourceBaseDriveApi api;

  Future<DriveWorkspaceData> loadWorkspace() async {
    if (!api.isConfigured) {
      throw StateError('SourceBase Supabase client is not configured.');
    }

    final response = await api.invoke('drive_bootstrap');
    final data = response['data'];
    if (data is Map) {
      return _workspaceFromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Drive workspace response is empty.');
  }

  Future<GcsUploadSession> createUploadSession(DriveUploadDraft draft) async {
    final session = await api.createUploadSession(draft);
    if (!session.isUsable) {
      throw StateError('Yükleme bağlantısı alınamadı. Lütfen tekrar deneyin.');
    }
    return session;
  }

  Future<DriveCourse> createCourse(String title) async {
    final response = await api.createCourse(title);
    final row = _requiredDataRow(response, 'Ders oluşturulamadı.');
    return _courseFromRow(row, const [], const []);
  }

  Future<DriveSection> createSection({
    required String courseId,
    required String title,
  }) async {
    final response = await api.createSection(courseId: courseId, title: title);
    return _sectionFromRow(
      _requiredDataRow(response, 'Bölüm oluşturulamadı.'),
      const [],
      null,
    );
  }

  Future<DriveCourse> renameCourse({
    required String courseId,
    required String title,
  }) async {
    final response = await api.renameCourse(courseId: courseId, title: title);
    final row = _requiredDataRow(response, 'Ders yeniden adlandırılamadı.');
    return _courseFromRow(row, const [], const []);
  }

  Future<DriveSection> renameSection({
    required String sectionId,
    required String title,
  }) async {
    final response = await api.renameSection(
      sectionId: sectionId,
      title: title,
    );
    return _sectionFromRow(
      _requiredDataRow(response, 'Bölüm yeniden adlandırılamadı.'),
      const [],
      null,
    );
  }

  Future<void> deleteCourse(String courseId) async {
    await api.deleteCourse(courseId);
  }

  Future<void> deleteSection(String sectionId) async {
    await api.deleteSection(sectionId);
  }

  Future<DriveFile> completeUpload({
    required PickedDriveFile file,
    required String objectName,
    required String courseId,
    required String sectionId,
    required String courseTitle,
    required String sectionTitle,
  }) async {
    final response = await api.completeUpload(
      objectName: objectName,
      courseId: courseId,
      sectionId: sectionId,
      fileName: file.name,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
    );
    final row = _requiredDataRow(response, 'Yüklenen dosya kaydı alınamadı.');
    return _fileFromRow(row, courseTitle, sectionTitle, const []);
  }

  Future<GeneratedOutput> createGeneratedOutput({
    required DriveFile file,
    required GeneratedKind kind,
  }) async {
    final jobType = _jobTypeForGeneratedKind(kind);
    int? itemCount;
    String? jobId;
    if (jobType != null) {
      final jobResponse = await api.createGenerationJob(
        fileId: file.id,
        jobType: jobType,
        count: _defaultGenerationCount(kind),
      );
      jobId = _text((jobResponse['data'] as Map?)?['jobId']);
      if (jobId.isEmpty) {
        throw StateError('AI üretim işi başlatılamadı.');
      }
      await api.processGenerationJob(jobId);
      final content = await _waitForGeneratedContent(api, jobId);
      itemCount = _contentItemCount(content);
    }
    final response = await api.createGeneratedOutput(
      fileId: file.id,
      kind: kind,
      itemCount: itemCount,
      jobId: jobId,
    );
    return _outputFromRow(
      _requiredDataRow(response, 'Üretilen içerik kaydı alınamadı.'),
    );
  }
}

DriveWorkspaceData _workspaceFromJson(Map<String, dynamic> json) {
  final rawCourses = _list(json['courses']);
  final rawSections = _list(json['sections']);
  final rawFiles = _list(json['files']);
  final rawOutputs = _list(
    json['generatedOutputs'] ?? json['generated_outputs'],
  );

  if (rawCourses.isEmpty) {
    return DriveWorkspaceData.empty;
  }

  final courses = rawCourses
      .map(
        (course) => _courseFromRow(course, rawSections, rawFiles, rawOutputs),
      )
      .toList();
  final files = courses
      .expand((course) => course.sections)
      .expand((section) => section.files)
      .toList();
  final recent = files.take(5).toList();
  final collections = files
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

Future<Object?> _waitForGeneratedContent(
  SourceBaseDriveApi api,
  String jobId,
) async {
  const maxAttempts = 24;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final statusResponse = await api.getJobStatus(jobId);
    final statusData = statusResponse['data'];
    final status = statusData is Map ? _text(statusData['status']) : '';
    if (status == 'completed') {
      final contentResponse = await api.getGeneratedContent(jobId);
      final contentData = contentResponse['data'];
      return contentData is Map ? contentData['content'] : null;
    }
    if (status == 'failed') {
      final message = statusData is Map
          ? _text(statusData['errorMessage'], fallback: 'AI üretimi başarısız.')
          : 'AI üretimi başarısız.';
      throw StateError(message);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError('AI üretimi zaman aşımına uğradı.');
}

DriveCourse _courseFromRow(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> allSections,
  List<Map<String, dynamic>> allFiles, [
  List<Map<String, dynamic>> allOutputs = const [],
]) {
  final id = _text(row['id']);
  final title = _text(row['title'], fallback: 'Yeni Ders');
  final updatedAt = _text(
    row['updated_at'],
    fallback: _text(row['created_at']),
  );
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
    updatedLabel: 'Son güncelleme ${_dateLabel(updatedAt)}',
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
  final status = _fileStatusFromRow(row);
  final pageCount = _int(row['page_count']);
  return DriveFile(
    id: id,
    title: _text(row['title'], fallback: _text(row['original_filename'])),
    kind: _kindFromText(
      _text(row['file_type'], fallback: _text(row['mime_type'])),
    ),
    sizeLabel: _sizeLabel(_int(row['size_bytes'])),
    pageLabel: _pageLabelForFile(status, pageCount),
    updatedLabel: _dateLabel(
      _text(row['updated_at'], fallback: _text(row['created_at'])),
    ),
    courseTitle: courseTitle,
    sectionTitle: sectionTitle,
    status: status,
    generated: allOutputs
        .where((output) => _text(output['source_file_id']) == id)
        .map(_outputFromRow)
        .toList(),
  );
}

GeneratedOutput _outputFromRow(Map<String, dynamic> row) {
  final rawType = _text(row['output_type'], fallback: _text(row['kind']));
  final kind = _generatedKindFromText(rawType);
  final metadata = _map(row['metadata']);
  final content = metadata['content'];
  final itemCount = _int(row['item_count']);
  final status = _text(row['status'], fallback: 'ready');
  return GeneratedOutput(
    id: _text(row['id']),
    sourceFileId: _text(row['source_file_id']),
    kind: kind,
    rawType: rawType,
    title: _text(row['title'], fallback: _generatedTitle(kind)),
    detail: _generatedOutputDetail(
      rawType: rawType,
      status: status,
      itemCount: itemCount,
      content: content,
    ),
    updatedLabel: _dateLabel(
      _text(row['updated_at'], fallback: _text(row['created_at'])),
    ),
    status: status,
    itemCount: itemCount,
    content: content,
    jobId: _text(metadata['jobId']),
  );
}

Map<String, dynamic> _dataRow(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map) {
    final dataMap = Map<String, dynamic>.from(data);
    final row = dataMap['row'];
    if (row is Map) return Map<String, dynamic>.from(row);
    if (dataMap['id'] != null) return dataMap;
  }
  return const {};
}

Map<String, dynamic> _requiredDataRow(
  Map<String, dynamic> response,
  String message,
) {
  final row = _dataRow(response);
  if (row.isEmpty) {
    throw StateError(message);
  }
  return row;
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

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
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

DriveItemStatus _statusFromText(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
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

DriveItemStatus _fileStatusFromRow(Map<String, dynamic> row) {
  final aiStatus = _text(row['ai_status']);
  final storageStatus = _text(row['status']);
  if (_int(row['size_bytes']) <= 0) return DriveItemStatus.failed;
  if (aiStatus.isNotEmpty) return _statusFromText(aiStatus);
  if (storageStatus.trim().toLowerCase() == 'uploaded') {
    return DriveItemStatus.processing;
  }
  return _statusFromText(storageStatus);
}

String _pageLabelForFile(DriveItemStatus status, int pageCount) {
  if (pageCount > 0) return '$pageCount sayfa';
  return switch (status) {
    DriveItemStatus.completed => 'Sayfa bilgisi yok',
    DriveItemStatus.processing => 'İşleniyor',
    DriveItemStatus.uploading => 'Yükleniyor',
    DriveItemStatus.failed => 'İşlenemedi',
    DriveItemStatus.draft => 'Taslak',
  };
}

DriveFileKind _kindFromText(String kind) {
  final normalized = kind.toLowerCase();
  return switch (normalized) {
    'pdf' || 'application/pdf' => DriveFileKind.pdf,
    'ppt' ||
    'pptx' ||
    'application/vnd.ms-powerpoint' ||
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
      DriveFileKind.pptx,
    'doc' || 'application/msword' => DriveFileKind.doc,
    'zip' ||
    'application/zip' ||
    'application/x-zip-compressed' => DriveFileKind.zip,
    _ => DriveFileKind.docx,
  };
}

GeneratedKind _generatedKindFromText(String kind) {
  final normalized = kind.trim();
  return switch (normalized) {
    'flashcard' || 'flashcards' => GeneratedKind.flashcard,
    'question' || 'questions' || 'quiz' => GeneratedKind.question,
    'algorithm' => GeneratedKind.algorithm,
    'comparison' => GeneratedKind.comparison,
    'table' => GeneratedKind.table,
    'podcast' || 'podcast_summary' || 'podcastSummary' => GeneratedKind.podcast,
    'infographic' => GeneratedKind.infographic,
    'mind_map' || 'mindMap' || 'mindmap' => GeneratedKind.mindMap,
    'summary' ||
    'exam_morning_summary' ||
    'examMorningSummary' ||
    'clinical_scenario' ||
    'clinicalScenario' ||
    'learning_plan' ||
    'learningPlan' => GeneratedKind.summary,
    _ => GeneratedKind.summary,
  };
}

String _generatedOutputDetail({
  required String rawType,
  required String status,
  required int itemCount,
  required Object? content,
}) {
  final normalizedStatus = status.trim().toLowerCase();
  if (normalizedStatus == 'failed' || normalizedStatus == 'error') {
    return 'Üretim tamamlanamadı';
  }
  if (!_isSupportedGeneratedOutputType(rawType)) {
    return 'Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor.';
  }
  final preview = _generatedContentPreview(content);
  if (itemCount > 0 && preview.isNotEmpty) return '$itemCount öğe • $preview';
  if (itemCount > 0) return '$itemCount öğe';
  if (preview.isNotEmpty) return preview;
  if (normalizedStatus == 'ready' || normalizedStatus == 'completed') {
    return 'Sonuç oluşturuldu';
  }
  return 'Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor.';
}

bool _isSupportedGeneratedOutputType(String rawType) {
  return switch (rawType.trim()) {
    'flashcard' ||
    'flashcards' ||
    'question' ||
    'questions' ||
    'quiz' ||
    'summary' ||
    'exam_morning_summary' ||
    'examMorningSummary' ||
    'algorithm' ||
    'comparison' ||
    'table' ||
    'podcast' ||
    'podcast_summary' ||
    'podcastSummary' ||
    'infographic' ||
    'mind_map' ||
    'mindMap' ||
    'mindmap' ||
    'clinical_scenario' ||
    'clinicalScenario' ||
    'learning_plan' ||
    'learningPlan' => true,
    _ => false,
  };
}

String _generatedContentPreview(Object? content) {
  final text = _firstGeneratedText(content).replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '';
  return text.length > 120 ? '${text.substring(0, 120)}...' : text;
}

String _firstGeneratedText(Object? value) {
  if (value is String) return value.trim();
  if (value is List) {
    for (final item in value) {
      final text = _firstGeneratedText(item);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
  if (value is Map) {
    for (final key in const [
      'title',
      'front',
      'question',
      'summary',
      'fullText',
      'answer',
      'description',
      'body',
      'text',
      'prompt',
    ]) {
      final text = _firstGeneratedText(value[key]);
      if (text.isNotEmpty) return text;
    }
    for (final key in const [
      'cards',
      'flashcards',
      'questions',
      'bulletPoints',
      'must_know',
      'commonly_confused',
      'clinical_tus_tips',
      'self_check',
      'steps',
      'rows',
      'segments',
      'chapters',
      'days',
      'nodes',
      'branches',
      'sections',
    ]) {
      final text = _firstGeneratedText(value[key]);
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

String _sizeLabel(int bytes) {
  if (bytes <= 0) return '-';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(mb >= 10 ? 1 : 1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String _dateLabel(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? 'Bugün' : raw;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) return 'Bugün';
  if (date == today.subtract(const Duration(days: 1))) return 'Dün';
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}

String? _jobTypeForGeneratedKind(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 'flashcard',
    GeneratedKind.question => 'quiz',
    GeneratedKind.summary => 'summary',
    GeneratedKind.algorithm => 'algorithm',
    GeneratedKind.comparison || GeneratedKind.table => 'comparison',
    GeneratedKind.podcast => 'podcast',
    GeneratedKind.infographic => 'infographic',
    GeneratedKind.mindMap => null,
  };
}

int? _defaultGenerationCount(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 20,
    GeneratedKind.question => 10,
    _ => null,
  };
}

int _contentItemCount(Object? content) {
  if (content is List) return content.length;
  if (content is Map) {
    for (final key in const [
      'cards',
      'flashcards',
      'questions',
      'bulletPoints',
      'must_know',
      'commonly_confused',
      'clinical_tus_tips',
      'self_check',
      'steps',
      'rows',
      'segments',
      'chapters',
      'days',
      'nodes',
      'branches',
      'sections',
      'teachingPoints',
      'objectives',
      'sessions',
    ]) {
      final value = content[key];
      if (value is List && value.isNotEmpty) return value.length;
    }
  }
  return 1;
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
    GeneratedKind.infographic => 'İnfografik',
    GeneratedKind.mindMap => 'Zihin Haritası',
  };
}
