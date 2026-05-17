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

  bool get hasSupportedExtension {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.zip');
  }

  bool get hasReadableContent => sizeBytes > 0 && bytes.isNotEmpty;
}
