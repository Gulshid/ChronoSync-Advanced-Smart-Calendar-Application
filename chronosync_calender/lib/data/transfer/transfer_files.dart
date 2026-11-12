import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [content] to a temporary file and opens the system share sheet.
Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content, flush: true);
  await Share.shareXFiles([XFile(file.path)], subject: subject);
}

/// Lets the user pick a file with one of [extensions] and returns its text, or null if cancelled.
Future<String?> pickTextFile(List<String> extensions) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  return File(path).readAsString();
}
