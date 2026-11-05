import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/poster.dart';

class PosterExportHost extends StatefulWidget {
  const PosterExportHost({super.key});

  static Future<Uint8List?> capture(Design design) {
    final state = _PosterExportHostState._instance;
    if (state == null) return Future<Uint8List?>.value();
    return state.capture(design);
  }

  @override
  State<PosterExportHost> createState() => _PosterExportHostState();
}

class _PosterExportHostState extends State<PosterExportHost> {
  static _PosterExportHostState? _instance;

  final GlobalKey _boundaryKey = GlobalKey();
  Design? _design;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  Future<Uint8List?> capture(Design design) async {
    try {
      await _precache(context, design);
      if (!mounted) return null;
      setState(() => _design = design);
      RenderRepaintBoundary? boundary;
      for (var attempt = 0; attempt < 4; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null && !boundary.debugNeedsPaint) break;
      }
      if (boundary == null) {
        debugPrint('Publish image error: poster was not painted');
        return null;
      }
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error, stackTrace) {
      debugPrint('Publish image error: $error\n$stackTrace');
      return null;
    } finally {
      if (mounted && _design != null) setState(() => _design = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    if (design == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 1080,
        maxWidth: 1080,
        minHeight: 1080,
        maxHeight: 1080,
        child: RepaintBoundary(
          key: _boundaryKey,
          child: SizedBox(
            width: 1080,
            height: 1080,
            child: PosterView(design: design),
          ),
        ),
      ),
    );
  }
}

Future<void> publishCurrentDesign(BuildContext context) async {
  final design = context.read<CreatorCubit>().state.current;
  if (design == null) return;
  final poster = await PosterExportHost.capture(design);
  if (!context.mounted) return;
  await context.read<CreatorCubit>().publish(poster: poster);
}

Future<void> publishListedDesign(BuildContext context, Design design, bool published) async {
  if (published) {
    await context.read<CreatorCubit>().togglePublished(design.id);
    return;
  }
  final poster = await PosterExportHost.capture(design);
  if (!context.mounted) return;
  await context.read<CreatorCubit>().togglePublished(design.id, poster: poster);
}

Future<void> _precache(BuildContext context, Design design) async {
  final providers = <ImageProvider>[
    if (design.backgroundImage != null) MemoryImage(design.backgroundImage!),
    for (final element in design.elements)
      if (element.imageBytes != null) MemoryImage(element.imageBytes!),
  ];
  await Future.wait(providers.map((provider) => precacheImage(provider, context)));
}
