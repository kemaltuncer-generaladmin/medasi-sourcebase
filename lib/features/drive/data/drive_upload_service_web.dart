// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'drive_upload_payload.dart';

class DriveUploadService {
  const DriveUploadService();

  Future<PickedDriveFile?> pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.ppt,.pptx,.doc,.docx,.zip,application/pdf'
      ..multiple = false;
    final picked = Completer<PickedDriveFile?>();
    input.onChange.first.then((_) async {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        picked.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final result = reader.result;
      final bytes = result is ByteBuffer
          ? Uint8List.view(result)
          : Uint8List.fromList(const []);
      picked.complete(
        PickedDriveFile(
          name: file.name,
          contentType: file.type.isNotEmpty
              ? file.type
              : _fallbackContentType(file.name),
          sizeBytes: file.size,
          bytes: bytes,
        ),
      );
    });
    input.click();
    return picked.future;
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Map<String, String> headers,
    required PickedDriveFile file,
  }) async {
    await html.HttpRequest.request(
      uploadUrl,
      method: 'PUT',
      requestHeaders: headers,
      sendData: file.bytes,
    );
  }

  String _fallbackContentType(String fileName) {
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
