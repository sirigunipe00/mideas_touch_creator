import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/src/catalog.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/poster.dart';
import 'package:mideas_touch_creator/src/poster_capture.dart';
import 'package:mideas_touch_creator/src/theme.dart';
import 'package:mideas_touch_creator/src/ui.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const StudioHeader(),
            const _FrozenCanvas(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 20),
                children: const [
                  ToolSection(),
                  PanelSection(),
                  DetailsSection(),
                ],
              ),
            ),
            const ViewSwitch(),
          ],
        ),
      ),
    );
  }
}

class _FrozenCanvas extends StatefulWidget {
  const _FrozenCanvas();

  @override
  State<_FrozenCanvas> createState() => _FrozenCanvasState();
}

class _FrozenCanvasState extends State<_FrozenCanvas> {
  static const _minZoom = 0.5;
  static const _maxZoom = 3.0;
  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _boxWidth = 0;

  void _onPinch(double scaleDelta, Offset panDelta) {
    setState(() {
      _zoom = (_zoom * scaleDelta).clamp(_minZoom, _maxZoom);
      _offset += panDelta;
      _clampOffset();
    });
  }

  void _stepZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(_minZoom, _maxZoom);
      _clampOffset();
    });
  }

  void _resetZoom() {
    setState(() {
      _zoom = 1;
      _offset = Offset.zero;
    });
  }

  void _clampOffset() {
    if (_zoom <= 1 || _boxWidth <= 0) {
      _offset = Offset.zero;
      return;
    }
    final limit = _boxWidth * (_zoom - 1) / 2;
    _offset = Offset(_offset.dx.clamp(-limit, limit), _offset.dy.clamp(-limit, limit));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PosterSection(
          zoom: _zoom,
          offset: _offset,
          onPinch: _onPinch,
          onMeasured: (width) => _boxWidth = width,
        ),
        UndoSection(
          zoom: _zoom,
          canZoomOut: _zoom > _minZoom,
          canZoomIn: _zoom < _maxZoom,
          onZoomOut: () => _stepZoom(-0.25),
          onZoomIn: () => _stepZoom(0.25),
          onZoomReset: _resetZoom,
        ),
      ],
    );
  }
}

class PosterSection extends StatelessWidget {
  const PosterSection({
    required this.zoom,
    required this.offset,
    required this.onPinch,
    required this.onMeasured,
    super.key,
  });

  final double zoom;
  final Offset offset;
  final void Function(double scaleDelta, Offset panDelta) onPinch;
  final ValueChanged<double> onMeasured;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) =>
          previous.current != current.current ||
          previous.selected != current.selected ||
          previous.showGuide != current.showGuide ||
          previous.removingBackground != current.removingBackground,
      builder: (context, state) {
        final design = state.current;
        if (design == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 32) * 0.76;
              onMeasured(width);
              return Center(
                child: SizedBox(
                  width: width,
                  height: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [context.colors.shadow],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Transform.translate(
                        offset: offset,
                        child: Transform.scale(
                          scale: zoom,
                          child: PosterView(
                            design: design,
                            selected: state.selected,
                            interactive: true,
                            showGuide: state.showGuide,
                            removing: state.removingBackground,
                            onPinch: onPinch,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class UndoSection extends StatelessWidget {
  const UndoSection({
    required this.zoom,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onZoomReset,
    super.key,
  });

  final double zoom;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Tap an item, then drag to move · bottom dot to resize · top dot to rotate',
            textAlign: TextAlign.center,
            style: poppins(colors, size: 11, color: colors.muted, height: 1.3),
          ),
        ),
        BlocBuilder<CreatorCubit, CreatorState>(
          buildWhen: (previous, current) => previous.history != current.history || previous.future != current.future,
          builder: (context, state) {
            final cubit = context.read<CreatorCubit>();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SquareButton(
                    dimmed: !state.canUndo,
                    onTap: cubit.undo,
                    child: Text('↶', style: poppins(colors, size: 18, height: 1)),
                  ),
                  const SizedBox(width: 8),
                  SquareButton(
                    dimmed: !state.canRedo,
                    onTap: cubit.redo,
                    child: Text('↷', style: poppins(colors, size: 18, height: 1)),
                  ),
                  const SizedBox(width: 18),
                  SquareButton(
                    dimmed: !canZoomOut,
                    onTap: canZoomOut ? onZoomOut : null,
                    child: Text('−', style: poppins(colors, size: 18, height: 1)),
                  ),
                  GestureDetector(
                    onTap: onZoomReset,
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        '${(zoom * 100).round()}%',
                        textAlign: TextAlign.center,
                        style: poppins(colors, size: 12, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SquareButton(
                    dimmed: !canZoomIn,
                    onTap: canZoomIn ? onZoomIn : null,
                    child: Text('+', style: poppins(colors, size: 18, height: 1)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class ToolSection extends StatelessWidget {
  const ToolSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.tool != current.tool || previous.selected != current.selected,
      builder: (context, state) {
        final colors = context.colors;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            children: [
              for (final tool in Catalog.tools)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => context.read<CreatorCubit>().toggleTool(tool.$1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: state.tool == tool.$1 && state.selected < 0 ? colors.primaryLight2 : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            children: [
                              Text(tool.$2, style: const TextStyle(fontSize: 19, height: 1.1)),
                              const SizedBox(height: 2),
                              Text(
                                tool.$3,
                                style: poppins(
                                  colors,
                                  size: 10,
                                  height: 1.1,
                                  color: state.tool == tool.$1 && state.selected < 0 ? colors.text : colors.muted,
                                  weight: state.tool == tool.$1 && state.selected < 0 ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PanelSection extends StatelessWidget {
  const PanelSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) =>
          previous.formTick != current.formTick ||
          previous.tool != current.tool ||
          previous.selected != current.selected ||
          previous.imageQuery != current.imageQuery,
      builder: (context, state) {
        final design = state.current;
        if (design == null) return const SizedBox.shrink();
        if (state.selected >= 0 && state.selected < design.elements.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _Properties(element: design.elements[state.selected], index: state.selected),
          );
        }
        if (state.tool == null) return const SizedBox.shrink();
        return _ToolPanel(tool: state.tool!, design: design, query: state.imageQuery);
      },
    );
  }
}

class _ToolPanel extends StatelessWidget {
  const _ToolPanel({required this.tool, required this.design, required this.query});

  final EditorTool tool;
  final Design design;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<CreatorCubit>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: switch (tool) {
        EditorTool.text => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                AppButton(label: '+ Heading', ghost: true, onPressed: cubit.addHeading),
                const SizedBox(width: 8),
                AppButton(label: '+ Subtitle', ghost: true, onPressed: cubit.addSubtitle),
              ],
            ),
          ),
        EditorTool.designs => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text('Start from a ready layout', style: poppins(colors, size: 12, color: colors.muted)),
              ),
              SizedBox(
                height: 156,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  itemCount: Catalog.templates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final template = Catalog.templates[index];
                    return GestureDetector(
                      onTap: () => cubit.applyTemplate(template.id),
                      child: Container(
                        width: 150,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [colors.shadow],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PosterView(design: template),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        EditorTool.images => _ImageTool(query: query),
        EditorTool.elements => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ShapeChoice(label: '●', onTap: cubit.addCircle),
                const SizedBox(width: 8),
                _ShapeChoice(label: '■', onTap: cubit.addSquare),
                const SizedBox(width: 8),
                _ShapeChoice(label: '▬', onTap: cubit.addBar),
              ],
            ),
          ),
        EditorTool.background => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UploadButton(
                  label: design.backgroundImage != null ? '✓ Background uploaded · change' : '⬆ Upload background from gallery',
                  onTap: () => cubit.pickImage(ImageSlot.background),
                ),
                if (design.backgroundImage != null)
                  GestureDetector(
                    onTap: cubit.removeUploadedBackground,
                    child: Text('Remove uploaded background', style: poppins(colors, size: 12, color: colors.muted)),
                  ),
                const SizedBox(height: 8),
                _BackgroundRow(design: design),
              ],
            ),
          ),
      },
    );
  }
}

class _ImageTool extends StatelessWidget {
  const _ImageTool({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<CreatorCubit>();
    final matches = <int>[
      for (var i = 0; i < Catalog.stickers.length; i++)
        if (Catalog.stickers[i].keywords.contains(query.toLowerCase())) i,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              SyncedField(
                key: const Key('image-search'),
                value: query,
                hint: 'Search images...',
                onChanged: cubit.setImageQuery,
              ),
              UploadButton(
                label: '⬆ Upload image from gallery',
                onTap: () => cubit.pickImage(ImageSlot.selectedOrNew),
              ),
            ],
          ),
        ),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('No images found', style: poppins(colors, color: colors.muted)),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: matches.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final sticker = Catalog.stickers[matches[index]];
              return _EmojiCell(
                emoji: sticker.emoji,
                fontSize: 30,
                onTap: () => cubit.addEmoji(matches[index]),
              );
            },
          ),
      ],
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.element, required this.index});

  final DesignElement element;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<CreatorCubit>();
    final title = switch (element.kind) {
      ElementKind.text => 'Text',
      ElementKind.shape => 'Shape',
      ElementKind.image => 'Image',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: poppins(colors, weight: FontWeight.w600)),
              const Spacer(),
              SquareButton(
                onTap: cubit.deleteSelected,
                child: const Text('🗑', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              SquareButton(
                onTap: cubit.clearSelection,
                child: Text('✓', style: poppins(colors, weight: FontWeight.w600)),
              ),
            ],
          ),
          if (element.kind == ElementKind.text) ...[
            const FieldLabel('Text'),
            SyncedField(
              key: ValueKey('prop-text-$index'),
              value: element.text.replaceAll('\n', ' / '),
              onChanged: (value) => cubit.setSelectedText(value.replaceAll(' / ', '\n')),
            ),
            const FieldLabel('Font'),
            _FontMenu(font: element.font),
            const FieldLabel('Size'),
            Row(
              children: [
                SquareButton(onTap: () => cubit.bumpFontSize(-2), child: Text('−', style: poppins(colors, size: 18))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: SyncedField(
                    key: ValueKey('prop-size-$index-${element.size.round()}'),
                    value: element.size.round().toString(),
                    live: false,
                    textAlign: TextAlign.center,
                    keyboard: TextInputType.number,
                    onChanged: (value) {
                      final size = double.tryParse(value);
                      if (size != null) cubit.setFontSize(size);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SquareButton(onTap: () => cubit.bumpFontSize(2), child: Text('+', style: poppins(colors, size: 18))),
                const SizedBox(width: 8),
                _ColorSwatch(
                  color: element.color,
                  onTap: () async {
                    final next = await showColorPicker(context, element.color);
                    if (next != null) cubit.setTextColor(next);
                  },
                ),
              ],
            ),
            const FieldLabel('Style and alignment'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SquareButton(
                  active: element.bold,
                  onTap: cubit.toggleBold,
                  child: Text('B', style: poppins(colors, weight: FontWeight.w700)),
                ),
                SquareButton(
                  active: element.italic,
                  onTap: cubit.toggleItalic,
                  child: Text('I', style: poppins(colors, size: 16).copyWith(fontStyle: FontStyle.italic)),
                ),
                SquareButton(
                  active: element.underline,
                  onTap: cubit.toggleUnderline,
                  child: Text('U', style: poppins(colors).copyWith(decoration: TextDecoration.underline)),
                ),
                for (final align in PosterAlign.values)
                  SquareButton(
                    active: element.align == align,
                    onTap: () => cubit.setAlign(align),
                    child: Text(_alignLabel(align), style: poppins(colors, size: 12)),
                  ),
              ],
            ),
          ],
          if (element.kind == ElementKind.shape) ...[
            const FieldLabel('Colour'),
            _ColorSwatch(
              color: element.fill.alpha == 255 ? element.fill : Colors.white,
              wide: true,
              onTap: () async {
                final current = element.fill.alpha == 255 ? element.fill : Colors.white;
                final next = await showColorPicker(context, current);
                if (next != null) cubit.setShapeColor(next);
              },
            ),
          ],
          if (element.kind == ElementKind.image) ...[
            if (element.imageBytes == null) ...[
              const SizedBox(height: 10),
              AppButton(
                label: element.photo ? '✂ Remove Background' : '✓ Background removed',
                ghost: true,
                expand: true,
                onPressed: element.photo ? cubit.removeBackground : null,
              ),
            ],
            UploadButton(
              label: '⬆ Replace from gallery',
              onTap: () => cubit.pickImage(ImageSlot.selectedOrNew),
            ),
            const FieldLabel('Change image'),
            _EmojiStrip(selected: element.imageBytes == null ? element.emoji : null, onTap: cubit.addEmoji),
          ],
          if (element.kind != ElementKind.text)
            _ValueSlider(
              label: 'Size',
              min: 8,
              max: 90,
              value: element.w.clamp(8.0, 90.0).toDouble(),
              onChangeStart: cubit.beginLive,
              onChanged: cubit.setWidth,
              onChangeEnd: cubit.endLive,
            ),
          _ValueSlider(
            label: 'Rotate',
            min: -180,
            max: 180,
            value: element.rotation.clamp(-180.0, 180.0).toDouble(),
            suffix: '°',
            onChangeStart: cubit.beginLive,
            onChanged: cubit.setRotation,
            onChangeEnd: cubit.endLive,
          ),
        ],
      ),
    );
  }
}

class DetailsSection extends StatelessWidget {
  const DetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) =>
          previous.formTick != current.formTick || previous.publishing != current.publishing,
      builder: (context, state) {
        final design = state.current;
        if (design == null) return const SizedBox.shrink();
        final cubit = context.read<CreatorCubit>();
        final texts = design.textIndexes;
        final imageIndex = design.firstImage;
        final image = imageIndex == null ? null : design.elements[imageIndex];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Design name'),
              SyncedField(
                key: const Key('design-name'),
                value: design.name,
                hint: 'e.g. Diwali Sale',
                onChanged: cubit.setDesignName,
              ),
              const FieldLabel('Category'),
              ChoiceChips(
                labels: Catalog.categories,
                selected: design.category,
                onSelected: cubit.setCategory,
              ),
              if (texts.isNotEmpty) ...[
                const FieldLabel('Headline'),
                SyncedField(
                  key: ValueKey('headline-${texts.first}'),
                  value: design.elements[texts.first].text,
                  maxLines: 2,
                  onChanged: cubit.setHeadline,
                ),
              ],
              if (texts.length > 1) ...[
                const FieldLabel('Subtitle'),
                SyncedField(
                  key: ValueKey('subtitle-${texts.last}'),
                  value: design.elements[texts.last].text,
                  onChanged: cubit.setSubtitle,
                ),
              ],
              if (image != null) ...[
                const FieldLabel('Main image'),
                _EmojiStrip(
                  selected: image.imageBytes == null ? image.emoji : null,
                  onTap: cubit.setMainEmoji,
                ),
                UploadButton(
                  label: image.imageBytes != null ? '✓ Image uploaded · change' : '⬆ Upload from gallery',
                  onTap: () => cubit.pickImage(ImageSlot.main),
                ),
              ],
              const FieldLabel('Background'),
              _BackgroundRow(design: design),
              UploadButton(
                label: design.backgroundImage != null
                    ? '✓ Background uploaded · change'
                    : '⬆ Upload background from gallery',
                onTap: () => cubit.pickImage(ImageSlot.background),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: AppButton(label: 'Save draft', ghost: true, onPressed: cubit.saveDraft)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: state.publishing
                          ? 'Publishing...'
                          : state.updatingPublished
                              ? 'Update'
                              : 'Publish',
                      onPressed: state.publishing ? null : () => publishCurrentDesign(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundRow extends StatelessWidget {
  const _BackgroundRow({required this.design});

  final Design design;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < Catalog.backgrounds.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => context.read<CreatorCubit>().setBackground(i),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    transform: GradientRotation(cssAngle(145)),
                    colors: [Catalog.backgrounds[i].$1, Catalog.backgrounds[i].$2],
                  ),
                  border: Border.all(
                    color: design.backgroundImage == null && design.bg1 == Catalog.backgrounds[i].$1
                        ? colors.primary
                        : colors.line,
                    width: design.backgroundImage == null && design.bg1 == Catalog.backgrounds[i].$1 ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmojiStrip extends StatelessWidget {
  const _EmojiStrip({required this.onTap, this.selected});

  final String? selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final emoji = Catalog.stickers[index].emoji;
        return _EmojiCell(
          emoji: emoji,
          fontSize: 22,
          selected: selected == emoji,
          onTap: () => onTap(index),
        );
      },
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    required this.emoji,
    required this.onTap,
    this.fontSize = 30,
    this.selected = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final double fontSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? colors.primary : colors.line, width: selected ? 2 : 1),
        ),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: fontSize))),
      ),
    );
  }
}

class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.line),
          ),
          child: Text(label, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}

class _FontMenu extends StatelessWidget {
  const _FontMenu({required this.font});

  final String font;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: colors.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          builder: (context) => _FontPicker(selected: font),
        );
        if (picked != null && context.mounted) context.read<CreatorCubit>().setFont(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(font, style: GoogleFonts.getFont(font, fontSize: 16, color: colors.text)),
            ),
            Text('⌄', style: poppins(colors, size: 16, color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.selected});

  final String selected;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  static final List<String> _all = GoogleFonts.asMap().keys.toList(growable: false);
  final TextEditingController _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final query = _filter.trim().toLowerCase();
    if (query.isEmpty) return _all;
    return [for (final name in _all) if (name.toLowerCase().contains(query)) name];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fonts = _visible;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              style: poppins(colors),
              decoration: InputDecoration(
                hintText: 'Search all fonts',
                hintStyle: poppins(colors, color: colors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.primary, width: 1.4),
                ),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final name = fonts[index];
                final selected = name == widget.selected;
                return ListTile(
                  dense: true,
                  selected: selected,
                  title: Text(name, style: GoogleFonts.getFont(name, fontSize: 18, color: colors.text)),
                  trailing: selected ? Text('✓', style: poppins(colors, weight: FontWeight.w700, color: colors.primary)) : null,
                  onTap: () => Navigator.pop(context, name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueSlider extends StatefulWidget {
  const _ValueSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;
  final String suffix;

  @override
  State<_ValueSlider> createState() => _ValueSliderState();
}

class _ValueSliderState extends State<_ValueSlider> {
  late double _value = widget.value;
  bool _dragging = false;

  @override
  void didUpdateWidget(_ValueSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.value != _value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: widget.min,
                max: widget.max,
                value: _value.clamp(widget.min, widget.max).toDouble(),
                onChangeStart: (_) {
                  _dragging = true;
                  widget.onChangeStart();
                },
                onChanged: (value) {
                  setState(() => _value = value);
                  widget.onChanged(value);
                },
                onChangeEnd: (_) {
                  _dragging = false;
                  widget.onChangeEnd();
                },
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${_value.round()}${widget.suffix}',
                textAlign: TextAlign.right,
                style: poppins(colors, size: 13, weight: FontWeight.w600, height: 1.2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.onTap, this.wide = false});

  final Color color;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : 46,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.line),
        ),
      ),
    );
  }
}

String _alignLabel(PosterAlign align) {
  final name = align.name;
  return name[0].toUpperCase() + name.substring(1);
}
