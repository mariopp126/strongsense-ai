import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Platform file boundary for backups.
///
/// Web and desktop use the native save dialog (on web, a browser download).
/// Android and iOS open the system share sheet, which is where users expect a
/// backup to go. Import uses the native document picker on every platform.
class BackupFileService {
  const BackupFileService();

  bool get _useShareSheet =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Returns true when the file was shared/saved, false when the user canceled.
  Future<bool> exportText({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (_useShareSheet) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(bytes, mimeType: mimeType, name: fileName),
          ],
          fileNameOverrides: <String>[fileName],
          subject: fileName,
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Save $fileName',
    );
    // On web the browser download has no path to return.
    return kIsWeb || saved != null;
  }

  /// Returns the selected JSON text, or null when the user cancels.
  Future<String?> pickJsonText() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Open a StrongSense backup',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: false);
  }
}
