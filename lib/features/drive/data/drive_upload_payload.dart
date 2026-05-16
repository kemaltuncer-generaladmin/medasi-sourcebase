import 'dart:typed_data';

class PickedDriveFile {
  const PickedDriveFile({
    required this.name,
    required this.contentType,
    required this.sizeBytes,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final int sizeBytes;
  final Uint8List bytes;
}
