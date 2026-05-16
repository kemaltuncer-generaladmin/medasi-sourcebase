import '../../auth/data/sourcebase_auth_backend.dart';
import 'drive_models.dart';

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
    if (data is Map<String, dynamic>) {
      if (data['ok'] == false) {
        final error = data['error'];
        throw StateError(
          error is Map
              ? error['message']?.toString() ?? 'SourceBase request failed.'
              : 'SourceBase request failed.',
        );
      }
      return data;
    }
    throw StateError('Unexpected SourceBase response.');
  }

  Future<GcsUploadSession> createUploadSession(DriveUploadDraft draft) async {
    final response = await invoke(
      'create_upload_session',
      payload: draft.toJson(),
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return GcsUploadSession.fromJson(data);
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

  Future<Map<String, dynamic>> createGeneratedOutput({
    required String fileId,
    required GeneratedKind kind,
    int? itemCount,
  }) {
    final payload = <String, dynamic>{'fileId': fileId, 'kind': kind.name};
    if (itemCount != null) payload['itemCount'] = itemCount;
    return invoke('create_generated_output', payload: payload);
  }

  Future<Map<String, dynamic>> createGenerationJob({
    required String fileId,
    required String jobType,
    int? count,
  }) {
    final payload = <String, dynamic>{'fileId': fileId, 'jobType': jobType};
    if (count != null) payload['count'] = count;
    return invoke('create_generation_job', payload: payload);
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) {
    return invoke('get_job_status', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> getGeneratedContent(String jobId) {
    return invoke('get_generated_content', payload: {'jobId': jobId});
  }

  Future<Map<String, dynamic>> centralAiChat(
    String message, {
    String? context,
  }) {
    return invoke(
      'central_ai_chat',
      payload: {
        'message': message,
        if (context != null && context.trim().isNotEmpty)
          'context': context.trim(),
      },
    );
  }
}
