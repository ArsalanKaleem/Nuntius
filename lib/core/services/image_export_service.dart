import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'file_service.dart';

/// The three sizes social apps actually want.
enum ShareFormat {
  story('Story', 1080, 1920),
  square('Square', 1080, 1080),
  landscape('Landscape', 1920, 1080);

  const ShareFormat(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;

  double get aspectRatio => width / height;
}

/// Turns an on-screen card into a PNG.
///
/// The card is captured from a live [RepaintBoundary] rather than rendered
/// offscreen. Offscreen rendering means hand-driving a PipelineOwner, which is
/// both fragile across Flutter versions and impossible to preview. Instead the
/// share sheet shows the card at the exact target aspect ratio and the capture
/// scales it up by whatever ratio hits the target pixel width — so what the
/// user sees is precisely what gets saved, at 1080px.
class ImageExportService {
  const ImageExportService(this._files);
  final FileService _files;

  Future<Uint8List> capture({
    required GlobalKey boundaryKey,
    required ShareFormat format,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError('The card is not on screen yet.');
    }
    final boundary = context.findRenderObject()! as RenderRepaintBoundary;

    // Scale so the exported width lands exactly on the format's pixel width.
    final pixelRatio = format.width / boundary.size.width;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode the image.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> share({
    required GlobalKey boundaryKey,
    required ShareFormat format,
    required String chatTitle,
    String? text,
  }) async {
    final bytes = await capture(boundaryKey: boundaryKey, format: format);
    final file = await _files.writeTemporary(
      '${_slug(chatTitle)}-wrapped-${format.name}.png',
      bytes,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: text,
    );
  }

  static String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'chat' : slug;
  }
}
