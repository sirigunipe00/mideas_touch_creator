import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';

TextStyle posterTextStyle(DesignElement element, double fontSize) {
  return GoogleFonts.getFont(
    element.font,
    fontSize: math.max(fontSize, 1),
    fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
    fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
    color: element.color,
    height: 1.15,
    decoration: element.underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: element.color,
  );
}

double textPixelSize(DesignElement element, double canvasWidth) => canvasWidth * element.size / 400;

class PosterView extends StatefulWidget {
  const PosterView({
    required this.design,
    this.selected = -1,
    this.interactive = false,
    this.showGuide = false,
    this.removing = false,
    super.key,
  });

  final Design design;
  final int selected;
  final bool interactive;
  final bool showGuide;
  final bool removing;

  @override
  State<PosterView> createState() => _PosterViewState();
}

class _PosterViewState extends State<PosterView> {
  final GlobalKey _boxKey = GlobalKey();
  _DragMode? _mode;
  int? _index;
  DesignElement? _origin;
  Offset? _start;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final canvas = Stack(
      key: _boxKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _PosterBackground(design: widget.design)),
        Positioned.fill(child: _elementLayer()),
        if (widget.showGuide)
          const Positioned.fill(
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 1, child: ColoredBox(color: Color(0xFFED0707))),
                ],
              ),
            ),
          ),
        if (widget.removing)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xA6140F00),
              child: Center(
                child: Text(
                  'Removing background...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ),
      ],
    );

    final framed = AspectRatio(aspectRatio: 1, child: canvas);
    if (!widget.interactive) return framed;
    return AspectRatio(
      aspectRatio: 1,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _PosterPanRecognizer: GestureRecognizerFactoryWithHandlers<_PosterPanRecognizer>(
            () => _PosterPanRecognizer(onDown: _down, onMove: _move, onUp: _up),
            (_) {},
          ),
        },
        child: canvas,
      ),
    );
  }

  Widget _elementLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final items = _layout(widget.design, size);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final item in items)
              Positioned(
                left: item.rect.left,
                top: item.rect.top,
                width: item.rect.width,
                height: item.rect.height,
                child: Transform.rotate(
                  angle: item.element.rotation * math.pi / 180,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _ElementBody(element: item.element, canvasWidth: size.width)),
                      if (item.index == widget.selected) ...[
                        const Positioned(
                          left: -2,
                          top: -2,
                          right: -2,
                          bottom: -2,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.fromBorderSide(BorderSide(color: Color(0xFFEFBF05), width: 2)),
                                boxShadow: [BoxShadow(color: Color(0x99000000), spreadRadius: 1)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -11,
                          bottom: -11,
                          child: _handle(),
                        ),
                        Positioned(
                          left: item.rect.width / 2 - 11,
                          top: -34,
                          child: _handle(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _handle() {
    return IgnorePointer(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEFBF05), width: 3),
        ),
      ),
    );
  }

  void _down(PointerDownEvent event) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(event.position);
    final hit = _hit(widget.design, widget.selected, box.size, local);
    if (hit == null) {
      _mode = null;
      context.read<CreatorCubit>().clearSelection();
      return;
    }
    _mode = hit.mode;
    _index = hit.index;
    _origin = hit.element;
    _start = event.position;
    _moved = false;
    context.read<CreatorCubit>().beginGesture(hit.index);
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    final start = _start;
    final index = _index;
    final mode = _mode;
    if (origin == null || start == null || index == null || mode == null) return;
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    final dx = (event.position.dx - start.dx) / size.width * 100;
    final dy = (event.position.dy - start.dy) / size.height * 100;
    var next = origin;
    var guide = false;
    if (mode == _DragMode.move) {
      var x = origin.x + dx;
      final y = origin.y + dy;
      if ((x + origin.w / 2 - 50).abs() < 1.5) {
        x = 50 - origin.w / 2;
        guide = true;
      }
      next = origin.copyWith(x: x, y: y);
    } else if (mode == _DragMode.resize) {
      final width = math.max(6.0, origin.w + dx);
      final ratio = origin.w == 0 ? 1.0 : width / origin.w;
      next = origin.copyWith(
        w: width,
        h: origin.kind == ElementKind.shape ? origin.h * ratio : origin.h,
        size: origin.kind == ElementKind.text ? origin.size * ratio : origin.size,
      );
    } else {
      final rect = _rectFor(origin, size);
      final center = box.localToGlobal(rect.center);
      var angle = math.atan2(event.position.dy - center.dy, event.position.dx - center.dx) * 180 / math.pi + 90;
      angle %= 360;
      if (angle > 180) angle -= 360;
      if (angle < -180) angle += 360;
      next = origin.copyWith(rotation: angle.roundToDouble());
    }
    _moved = true;
    context.read<CreatorCubit>().previewElement(index, next, guide: guide);
  }

  void _up(PointerEvent event) {
    if (_mode != null) {
      context.read<CreatorCubit>().endGesture(moved: _moved);
    }
    _mode = null;
    _origin = null;
    _index = null;
  }
}

enum _DragMode { move, resize, rotate }

class _Hit {
  const _Hit(this.index, this.element, this.mode);
  final int index;
  final DesignElement element;
  final _DragMode mode;
}

_Hit? _hit(Design design, int selected, Size size, Offset point) {
  final items = _layout(design, size);
  for (var i = items.length - 1; i >= 0; i--) {
    final item = items[i];
    final local = _toLocal(point, item.rect, item.element.rotation);
    if (item.index == selected) {
      final rotate = Rect.fromLTWH(item.rect.width / 2 - 11, -34, 22, 22);
      final resize = Rect.fromLTWH(item.rect.width - 11, item.rect.height - 11, 22, 22);
      if (rotate.contains(local)) return _Hit(item.index, item.element, _DragMode.rotate);
      if (resize.contains(local)) return _Hit(item.index, item.element, _DragMode.resize);
    }
    if (Rect.fromLTWH(0, 0, item.rect.width, item.rect.height).contains(local)) {
      return _Hit(item.index, item.element, _DragMode.move);
    }
  }
  return null;
}

Offset _toLocal(Offset point, Rect rect, double degrees) {
  final center = rect.center;
  final delta = point - center;
  final rad = -degrees * math.pi / 180;
  final turned = Offset(
    delta.dx * math.cos(rad) - delta.dy * math.sin(rad),
    delta.dx * math.sin(rad) + delta.dy * math.cos(rad),
  );
  return turned + center - rect.topLeft;
}

class _LaidOut {
  const _LaidOut(this.index, this.element, this.rect);
  final int index;
  final DesignElement element;
  final Rect rect;
}

List<_LaidOut> _layout(Design design, Size size) {
  if (size.width <= 0 || size.height <= 0) return const [];
  return [
    for (var i = 0; i < design.elements.length; i++)
      _LaidOut(i, design.elements[i], _rectFor(design.elements[i], size)),
  ];
}

Rect _rectFor(DesignElement element, Size size) {
  final left = element.x / 100 * size.width;
  final top = element.y / 100 * size.height;
  final width = math.max(element.w / 100 * size.width, 1.0);
  final double height;
  switch (element.kind) {
    case ElementKind.image:
      height = math.max(element.w / 100 * size.height, 1.0);
    case ElementKind.shape:
      height = math.max(element.h / 100 * size.height, 1.0);
    case ElementKind.text:
      final fontSize = textPixelSize(element, size.width);
      final painter = TextPainter(
        text: TextSpan(
          text: element.text.isEmpty ? ' ' : element.text,
          style: posterTextStyle(element, fontSize),
        ),
        textAlign: element.textAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);
      height = math.max(painter.height, 1.0);
  }
  return Rect.fromLTWH(left, top, width, height);
}

class _ElementBody extends StatelessWidget {
  const _ElementBody({required this.element, required this.canvasWidth});

  final DesignElement element;
  final double canvasWidth;

  @override
  Widget build(BuildContext context) {
    switch (element.kind) {
      case ElementKind.text:
        return Text(
          element.text,
          textAlign: element.textAlign,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: posterTextStyle(element, textPixelSize(element, canvasWidth)),
        );
      case ElementKind.shape:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: element.fill,
            borderRadius: _radius(element.radius, double.infinity, double.infinity),
          ),
        );
      case ElementKind.image:
        return _ImageBody(element: element, canvasWidth: canvasWidth);
    }
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.element, required this.canvasWidth});

  final DesignElement element;
  final double canvasWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final radius = BorderRadius.circular(side * 0.06);
        final bytes = element.imageBytes;
        const photoShadow = BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 4));
        const dropShadow = BoxShadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 6));
        final emoji = Text(
          element.emoji,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: canvasWidth * element.w * 0.62 / 100,
            height: 1,
            shadows: element.photo || bytes != null
                ? null
                : const [Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 6))],
          ),
        );
        if (bytes == null && !element.photo) {
          return Center(child: emoji);
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [element.photo ? photoShadow : dropShadow],
            gradient: bytes == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFCF4D3)],
                  )
                : null,
            image: bytes == null ? null : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
          child: Center(child: bytes == null ? emoji : const SizedBox.shrink()),
        );
      },
    );
  }
}

BorderRadius _radius(String radius, double width, double height) {
  if (radius == '50%') return BorderRadius.circular(999);
  if (radius == '999px') return BorderRadius.circular(999);
  final value = double.tryParse(radius.replaceAll('px', ''));
  if (value == null || value == 0) return BorderRadius.zero;
  return BorderRadius.circular(value);
}

class _PosterBackground extends StatelessWidget {
  const _PosterBackground({required this.design});

  final Design design;

  @override
  Widget build(BuildContext context) {
    final bytes = design.backgroundImage;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return CustomPaint(
      painter: _BackgroundPainter(design.bg1, design.bg2),
      child: const SizedBox.expand(),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter(this.c1, this.c2);

  final Color c1;
  final Color c2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          transform: const GradientRotation((145 - 90) * math.pi / 180),
          colors: [c1, c2],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.05),
      size.width * 0.32,
      Paint()..color = const Color(0x29FFFFFF),
    );
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.95),
      size.width * 0.24,
      Paint()..color = const Color(0x1AFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => oldDelegate.c1 != c1 || oldDelegate.c2 != c2;
}

class _PosterPanRecognizer extends OneSequenceGestureRecognizer {
  _PosterPanRecognizer({required this.onDown, required this.onMove, required this.onUp});

  final void Function(PointerDownEvent event) onDown;
  final void Function(PointerMoveEvent event) onMove;
  final void Function(PointerEvent event) onUp;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    onDown(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) onMove(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      onUp(event);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'poster-pan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
