import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';

class DocumentDownloadService {
  const DocumentDownloadService._();

  static Future<void> shareRemoteFile({
    required String url,
    required String title,
    required String mimeType,
    required String extension,
  }) async {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);

    if (bytes.isEmpty) {
      throw StateError('Document is empty or unavailable.');
    }

    await shareBytes(
      bytes: bytes,
      title: title,
      mimeType: mimeType,
      extension: extension,
    );
  }

  static Future<void> shareBytes({
    required Uint8List bytes,
    required String title,
    required String mimeType,
    required String extension,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'RentFlow document: $title',
        files: [
          XFile.fromData(
            bytes,
            mimeType: mimeType,
            name: fileName(title: title, extension: extension),
          ),
        ],
      ),
    );
  }

  static Future<void> shareLocalFile({
    required String path,
    required String title,
    required String mimeType,
    required String extension,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'RentFlow document: $title',
        files: [
          XFile(
            path,
            mimeType: mimeType,
            name: fileName(title: title, extension: extension),
          ),
        ],
      ),
    );
  }

  static String fileName({required String title, required String extension}) {
    final normalizedExtension = extension.startsWith('.')
        ? extension
        : '.$extension';
    var base = title.trim().isEmpty ? 'rentflow-document' : title.trim();
    base = base
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .toLowerCase();

    if (base.isEmpty) {
      base = 'rentflow-document';
    }

    if (base.length > 80) {
      base = base.substring(0, 80);
    }

    return base.endsWith(normalizedExtension.toLowerCase())
        ? base
        : '$base$normalizedExtension';
  }
}
