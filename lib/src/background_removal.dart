import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Removes a near-solid backdrop (black/gray card, studio backdrop, etc.)
/// so decorative main images sit cleanly on the template background.
Future<Uint8List> removeSolidBackground(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final source = frame.image;
  final raw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = source.width;
  final height = source.height;
  source.dispose();
  if (raw == null || width == 0 || height == 0) return bytes;

  final pixels = Uint8List.fromList(raw.buffer.asUint8List());
  final bg = _sampleBackground(pixels, width, height);

  // Already transparent / photographic: leave alone when corners aren't a flat key.
  if (!_isFlatBackdrop(pixels, width, height, bg)) return bytes;

  const hard = 38.0;
  const soft = 34.0;
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a == 0) continue;

    final distance = _distance(r, g, b, bg.$1, bg.$2, bg.$3);
    if (distance <= hard) {
      pixels[i + 3] = 0;
      continue;
    }
    if (distance < hard + soft) {
      final t = (distance - hard) / soft;
      pixels[i + 3] = (a * t).round().clamp(0, 255);
      // Despill dark fringe left by anti-aliasing against black/gray.
      pixels[i] = _mixToward(r, bg.$1, 1 - t);
      pixels[i + 1] = _mixToward(g, bg.$2, 1 - t);
      pixels[i + 2] = _mixToward(b, bg.$3, 1 - t);
    }
  }

  final cropped = _cropToOpaque(pixels, width, height);
  return await _encodePng(cropped.bytes, cropped.width, cropped.height) ?? bytes;
}

(int, int, int) _sampleBackground(Uint8List pixels, int width, int height) {
  final points = <(int, int)>[
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
    (width ~/ 2, 0),
    (width ~/ 2, height - 1),
    (0, height ~/ 2),
    (width - 1, height ~/ 2),
  ];
  var r = 0, g = 0, b = 0;
  for (final point in points) {
    final i = (point.$2 * width + point.$1) * 4;
    r += pixels[i];
    g += pixels[i + 1];
    b += pixels[i + 2];
  }
  final n = points.length;
  return (r ~/ n, g ~/ n, b ~/ n);
}

bool _isFlatBackdrop(Uint8List pixels, int width, int height, (int, int, int) bg) {
  final points = <(int, int)>[
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
    (width ~/ 2, 0),
    (width ~/ 2, height - 1),
    (0, height ~/ 2),
    (width - 1, height ~/ 2),
  ];
  var matches = 0;
  for (final point in points) {
    final i = (point.$2 * width + point.$1) * 4;
    if (_distance(pixels[i], pixels[i + 1], pixels[i + 2], bg.$1, bg.$2, bg.$3) <= 28) {
      matches++;
    }
  }
  if (matches < 6) return false;

  var edgeDiff = 0;
  final stepX = math.max(1, width ~/ 24);
  final stepY = math.max(1, height ~/ 24);
  for (var x = 0; x < width; x += stepX) {
    for (final y in [0, height - 1]) {
      final i = (y * width + x) * 4;
      if (_distance(pixels[i], pixels[i + 1], pixels[i + 2], bg.$1, bg.$2, bg.$3) > 28) {
        edgeDiff++;
      }
    }
  }
  for (var y = 0; y < height; y += stepY) {
    for (final x in [0, width - 1]) {
      final i = (y * width + x) * 4;
      if (_distance(pixels[i], pixels[i + 1], pixels[i + 2], bg.$1, bg.$2, bg.$3) > 28) {
        edgeDiff++;
      }
    }
  }
  return edgeDiff < 18;
}

double _distance(int r1, int g1, int b1, int r2, int g2, int b2) {
  final dr = (r1 - r2).toDouble();
  final dg = (g1 - g2).toDouble();
  final db = (b1 - b2).toDouble();
  return math.sqrt(dr * dr + dg * dg + db * db);
}

int _mixToward(int channel, int bg, double amount) {
  final cleaned = ((channel - bg * amount) / (1 - amount * 0.85)).round();
  return cleaned.clamp(0, 255);
}

({Uint8List bytes, int width, int height}) _cropToOpaque(Uint8List pixels, int width, int height) {
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] < 16) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < minX || maxY < minY) {
    return (bytes: pixels, width: width, height: height);
  }

  const pad = 2;
  minX = math.max(0, minX - pad);
  minY = math.max(0, minY - pad);
  maxX = math.min(width - 1, maxX + pad);
  maxY = math.min(height - 1, maxY + pad);
  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  if (cropW >= width - 4 && cropH >= height - 4) {
    return (bytes: pixels, width: width, height: height);
  }

  final out = Uint8List(cropW * cropH * 4);
  for (var y = 0; y < cropH; y++) {
    final src = ((minY + y) * width + minX) * 4;
    final dst = y * cropW * 4;
    out.setRange(dst, dst + cropW * 4, pixels, src);
  }
  return (bytes: out, width: cropW, height: cropH);
}

Future<Uint8List?> _encodePng(Uint8List pixels, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
