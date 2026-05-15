import 'drive_upload_payload.dart';

class DriveUploadService {
  const DriveUploadService();

  Future<PickedDriveFile?> pickFile() async {
    throw UnsupportedError('Dosya seçimi bu platformda henüz desteklenmiyor.');
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Map<String, String> headers,
    required PickedDriveFile file,
  }) async {
    throw UnsupportedError('Dosya yükleme bu platformda henüz desteklenmiyor.');
  }
}
