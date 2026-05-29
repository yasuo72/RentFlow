import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'document_download_service.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    required this.documentUrl,
    required this.title,
    super.key,
  });

  final String documentUrl;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final Future<String?> _pdfPathFuture = _downloadPdf();
  bool _downloading = false;

  Future<String?> _downloadPdf() async {
    if (widget.documentUrl.isEmpty) {
      return null;
    }

    final response = await Dio().get<List<int>>(
      widget.documentUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.documentUrl);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadForSaving() async {
    setState(() => _downloading = true);

    try {
      final path = await _pdfPathFuture;
      if (path == null) {
        throw StateError('PDF is not available.');
      }

      await DocumentDownloadService.shareLocalFile(
        path: path,
        title: widget.title,
        mimeType: 'application/pdf',
        extension: '.pdf',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to download PDF: $error')));
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: widget.documentUrl.isEmpty || _downloading
                ? null
                : _downloadForSaving,
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Open externally',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _pdfPathFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to open this PDF inside the app.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openExternally,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open externally'),
                    ),
                  ],
                ),
              ),
            );
          }

          return PDFView(filePath: snapshot.data!);
        },
      ),
    );
  }
}
