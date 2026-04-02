import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'gesture_storage_service.dart';

class GestureTransferService {
  final GestureStorageService _storageService = GestureStorageService();

  Future<File> exportRepositoryToTempFile() async {
    final repository = await _storageService.loadRepository();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${tempDir.path}/gabaykamay_gestures_$timestamp.json');
    await file.writeAsString(repository.toEncodedJson(), flush: true);
    return file;
  }

  Future<void> shareExportedRepository() async {
    final file = await exportRepositoryToTempFile();
    await shareFile(file);
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'GabayKamay gesture library export',
      subject: 'GabayKamay Gesture Library',
    );
  }

  Future<String?> pickImportFilePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select a GabayKamay gesture library export',
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single.path;
  }
}
