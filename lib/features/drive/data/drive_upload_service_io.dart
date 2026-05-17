import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'drive_upload_payload.dart';

class DriveUploadService {
  const DriveUploadService();

  Future<PickedDriveFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'zip'],
      withData: true,
    );
    final picked = result?.files.singleOrNull;
    if (picked == null) return null;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) {
      throw StateError('Dosya okunamadı.');
    }
    return PickedDriveFile(
      name: picked.name,
      contentType: _contentTypeFor(picked.name),
      sizeBytes: picked.size,
      bytes: bytes,
    );
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Map<String, String> headers,
    required PickedDriveFile file,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(uploadUrl));
      headers.forEach(request.headers.set);
      request.contentLength = file.bytes.length;
      request.add(file.bytes);
      onProgress?.call(.9);
      final response = await request.close();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      await response.drain<void>();
      if (!ok) {
        throw StateError('GCS upload failed: HTTP ${response.statusCode}');
      }
      onProgress?.call(1);
    } finally {
      client.close(force: true);
    }
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }
}
