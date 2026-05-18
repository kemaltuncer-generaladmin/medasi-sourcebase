import '../../auth/data/sourcebase_auth_backend.dart';
import 'drive_models.dart';

class SourceBaseApiException implements Exception {
  const SourceBaseApiException(this.message, {this.code, this.status});

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() {
    final prefix = code == null || code!.isEmpty ? '' : '$code: ';
    return '$prefix$message';
  }
}

class SourceBaseDriveApi {
  const SourceBaseDriveApi();

  bool get isConfigured => SourceBaseAuthBackend.client != null;

  Future<Map<String, dynamic>> invoke(
    String action, {
    Map<String, dynamic>? payload,
  }) async {
    final client = SourceBaseAuthBackend.client;
    if (client == null) {
      throw StateError('SourceBase Supabase client is not configured.');
    }

    final response = await client.functions.invoke(
      'sourcebase',
      body: {'action': action, 'payload': payload ?? const {}},
    );
    final data = response.data;
    if (data is Map) {
      final body = Map<String, dynamic>.from(data);
      if (body['ok'] == false) {
        final error = body['error'];
        throw SourceBaseApiException(
          error is Map
              ? error['message']?.toString() ?? 'SourceBase request failed.'
              : 'SourceBase request failed.',
          code: error is Map ? error['code']?.toString() : null,
          status: error is Map
              ? int.tryParse(error['status']?.toString() ?? '')
              : null,
        );
      }
      return body;
    }
    throw StateError('Unexpected SourceBase response.');
  }

  Future<GcsUploadSession> createUploadSession(DriveUploadDraft draft) async {
    final response = await invoke(
      'create_upload_session',
      payload: draft.toJson(),
    );
    final data = response['data'];
    if (data is Map) {
      return GcsUploadSession.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Upload session response is empty.');
  }

  Future<Map<String, dynamic>> completeUpload({
    required String objectName,
    required String courseId,
    required String sectionId,
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) async {
    return invoke(
      'complete_upload',
      payload: {
        'objectName': objectName,
        'courseId': courseId,
        'sectionId': sectionId,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
  }

  Future<Map<String, dynamic>> createCourse(String title) {
    return invoke('create_course', payload: {'title': title});
  }

  Future<Map<String, dynamic>> createSection({
    required String courseId,
    required String title,
  }) {
    return invoke(
      'create_section',
      payload: {'courseId': courseId, 'title': title},
    );
  }

  Future<Map<String, dynamic>> renameCourse({
    required String courseId,
    required String title,
  }) {
    return invoke(
      'rename_course',
      payload: {'courseId': courseId, 'title': title},
    );
  }

  Future<Map<String, dynamic>> renameSection({
    required String sectionId,
    required String title,
  }) {
    return invoke(
      'rename_section',
      payload: {'sectionId': sectionId, 'title': title},
    );
  }

  Future<Map<String, dynamic>> deleteCourse(String courseId) {
    return invoke('delete_course', payload: {'courseId': courseId});
  }

  Future<Map<String, dynamic>> deleteSection(String sectionId) {
    return invoke('delete_section', payload: {'sectionId': sectionId});
  }

  Future<Map<String, dynamic>> createGeneratedOutput({
    required String fileId,
    required GeneratedKind kind,
    int? itemCount,
    String? jobId,
  }) {
    return createGeneratedOutputByKind(
      fileId: fileId,
      kind: kind.name,
      itemCount: itemCount,
      jobId: jobId,
    );
  }

  Future<Map<String, dynamic>> createGeneratedOutputByKind({
    required String fileId,
    required String kind,
    int? itemCount,
    String? jobId,
  }) {
    final payload = <String, dynamic>{'fileId': fileId, 'kind': kind};
    if (itemCount != null) payload['itemCount'] = itemCount;
    if (jobId != null && jobId.trim().isNotEmpty) {
      payload['jobId'] = jobId.trim();
    }
    return invoke('create_generated_output', payload: payload);
  }

  Future<Map<String, dynamic>> createGenerationJob({
    required String fileId,
    required String jobType,
    List<String>? sourceIds,
    int? count,
    String? qualityTier,
    Map<String, dynamic>? options,
  }) {
    final payload = <String, dynamic>{'fileId': fileId, 'jobType': jobType};
    if (sourceIds != null && sourceIds.isNotEmpty) {
      payload['sourceIds'] = sourceIds;
    }
    if (count != null) payload['count'] = count;
    if (qualityTier != null && qualityTier.trim().isNotEmpty) {
      payload['quality_tier'] = qualityTier.trim();
    }
    if (options != null) {
      for (final entry in options.entries) {
        final value = entry.value;
        if (value == null) continue;
        if (value is String && value.trim().isEmpty) continue;
        payload[entry.key] = value;
      }
    }
    return invoke('create_generation_job', payload: payload);
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) {
    return invoke('get_job_status', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> processGenerationJob(String jobId) {
    return invoke('process_generation_job', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> getGeneratedContent(String jobId) {
    return invoke('get_generated_content', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> cancelJob(String jobId) {
    return invoke('cancel_job', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> centralAiChat(
    String message, {
    String? context,
    List<String>? fileIds,
  }) {
    final payload = <String, dynamic>{'message': message};
    if (context != null && context.trim().isNotEmpty) {
      payload['context'] = context.trim();
    }
    final cleanFileIds = fileIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanFileIds != null && cleanFileIds.isNotEmpty) {
      payload['fileIds'] = cleanFileIds;
    }
    return invoke('central_ai_chat', payload: payload);
  }
}
