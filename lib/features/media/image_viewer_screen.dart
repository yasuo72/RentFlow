import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'document_download_service.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageUrl,
    required this.title,
    super.key,
  });

  final String imageUrl;
  final String title;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _downloading = false;

  Future<void> _downloadImage() async {
    setState(() => _downloading = true);

    try {
      await DocumentDownloadService.shareRemoteFile(
        url: widget.imageUrl,
        title: widget.title,
        mimeType: _mimeTypeFor(widget.imageUrl),
        extension: _extensionFor(widget.imageUrl),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download image: $error')),
      );
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
            onPressed: widget.imageUrl.isEmpty || _downloading
                ? null
                : _downloadImage,
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: widget.imageUrl.isEmpty
          ? const Center(child: Text('Image is not available.'))
          : InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) =>
                      const Text('Unable to load image.'),
                ),
              ),
            ),
    );
  }

  static String _extensionFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (path.endsWith('.webp')) {
      return '.webp';
    }
    return '.png';
  }

  static String _mimeTypeFor(String url) {
    final extension = _extensionFor(url);
    return switch (extension) {
      '.jpg' => 'image/jpeg',
      '.webp' => 'image/webp',
      _ => 'image/png',
    };
  }
}
