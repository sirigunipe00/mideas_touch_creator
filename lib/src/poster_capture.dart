import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/poster.dart';

/// Key for the on-screen create poster. Prefer this for capture when present.
final GlobalKey posterPreviewBoundaryKey = GlobalKey(debugLabel: 'posterPreview');

class PosterExportHost extends StatefulWidget {
  const PosterExportHost({super.key});

  static Future<Uint8List?> capture(Design design, {GlobalKey? preferredKey}) async {
    final fromPreferred = preferredKey == null ? null : await captureKey(preferredKey);
    if (fromPreferred != null && fromPreferred.isNotEmpty) return fromPreferred;

    final fromPreview = await captureKey(posterPreviewBoundaryKey);
    if (fromPreview != null && fromPreview.isNotEmpty) return fromPreview;

    final state = _PosterExportHostState._instance;
    if (state == null) {
      debugPrint('Publish image error: export host is not mounted');
      return null;
    }
    return state.capture(design);
  }

  static Future<Uint8List?> captureKey(GlobalKey key) async {
    try {
      RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) return null;

      // Wait until the layer is painted. Only read debugNeedsPaint in debug —
      // in release that getter throws LateInitializationError.
      for (var attempt = 0; attempt < 20; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) return null;
        if (kDebugMode) {
          if (!boundary.debugNeedsPaint) break;
        } else if (attempt >= (kIsWeb ? 5 : 2)) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 16 + attempt * 8));
      }

      await Future<void>.delayed(Duration(milliseconds: kIsWeb ? 80 : 24));
      boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) return null;
      if (kDebugMode && boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null || !boundary.hasSize) return null;
        if (boundary.debugNeedsPaint) return null;
      }

      final image = await boundary.toImage(pixelRatio: _pixelRatioFor(boundary.size));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error, stackTrace) {
      debugPrint('Publish image error (key): $error\n$stackTrace');
      return null;
    }
  }

  @override
  State<PosterExportHost> createState() => _PosterExportHostState();
}

class _PosterExportHostState extends State<PosterExportHost> {
  static _PosterExportHostState? _instance;
  static const double _exportSize = 720;

  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'posterExport');
  Design? _design;
  Completer<Uint8List?>? _pending;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(null);
    }
    super.dispose();
  }

  Future<Uint8List?> capture(Design design) async {
    if (_pending != null) {
      return _pending!.future;
    }
    final completer = Completer<Uint8List?>();
    _pending = completer;
    try {
      await _precache(context, design).timeout(const Duration(seconds: 3), onTimeout: () {});
      if (!mounted) {
        completer.complete(null);
        return null;
      }
      setState(() => _design = design);
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(kIsWeb ? const Duration(milliseconds: 120) : const Duration(milliseconds: 50));

      Uint8List? bytes;
      for (var attempt = 0; attempt < 8; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        bytes = await PosterExportHost.captureKey(_boundaryKey);
        if (bytes != null && bytes.isNotEmpty) break;
        await Future<void>.delayed(Duration(milliseconds: 40 + attempt * 20));
      }
      completer.complete(bytes);
      return bytes;
    } catch (error, stackTrace) {
      debugPrint('Publish image error: $error\n$stackTrace');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    } finally {
      _pending = null;
      if (mounted && _design != null) {
        setState(() => _design = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    // Keep on-screen with tiny opacity so CanvasKit still paints (fully offscreen often fails on web).
    return Positioned(
      left: 0,
      top: 0,
      width: _exportSize,
      height: _exportSize,
      child: IgnorePointer(
        child: Opacity(
          opacity: design == null ? 0 : 0.01,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: ColoredBox(
              color: Colors.white,
              child: design == null
                  ? const SizedBox.expand()
                  : PosterView(design: design, selected: -1, interactive: false),
            ),
          ),
        ),
      ),
    );
  }
}

double _pixelRatioFor(Size size) {
  if (size.longestSide >= 900) return 1;
  if (kIsWeb) return 1;
  return 2;
}

Future<void> publishCurrentDesign(BuildContext context) async {
  final design = context.read<CreatorCubit>().state.current;
  if (design == null) return;
  final poster = await PosterExportHost.capture(design, preferredKey: posterPreviewBoundaryKey)
      .timeout(const Duration(seconds: 10), onTimeout: () {
    debugPrint('Publish image error: capture timed out');
    return null;
  });
  if (!context.mounted) return;
  await context.read<CreatorCubit>().publish(poster: poster);
}

Future<void> saveCurrentDesign(BuildContext context) async {
  final cubit = context.read<CreatorCubit>();
  final design = cubit.state.current;
  if (design == null) return;
  // Save the draft immediately so a slow/failed image capture never blocks saving.
  cubit.saveDraft();
  final poster = await PosterExportHost.capture(design, preferredKey: posterPreviewBoundaryKey)
      .timeout(const Duration(seconds: 8), onTimeout: () {
    debugPrint('Draft image error: capture timed out');
    return null;
  });
  if (!context.mounted || poster == null || poster.isEmpty) return;
  await context.read<CreatorCubit>().syncDraftPoster(poster);
}

Future<void> publishListedDesign(BuildContext context, Design design, bool published) async {
  if (published) {
    await context.read<CreatorCubit>().togglePublished(design.id);
    return;
  }
  final poster = await PosterExportHost.capture(design).timeout(const Duration(seconds: 10), onTimeout: () {
    debugPrint('Publish image error: capture timed out');
    return null;
  });
  if (!context.mounted) return;
  await context.read<CreatorCubit>().togglePublished(design.id, poster: poster);
}

Future<void> _precache(BuildContext context, Design design) async {
  final providers = <ImageProvider>[
    if (design.backgroundImage != null) MemoryImage(design.backgroundImage!),
    for (final element in design.elements)
      if (element.imageBytes != null) MemoryImage(element.imageBytes!),
  ];
  if (providers.isEmpty) return;
  await Future.wait(
    providers.map(
      (provider) => precacheImage(provider, context).catchError((Object _) {}),
    ),
  );
}
