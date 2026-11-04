import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/src/catalog.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/poster.dart';
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
            const ViewSwitch(),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 20),
                children: const [
                  PosterSection(),
                  UndoSection(),
                  ToolSection(),
                  PanelSection(),
                  DetailsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosterSection extends StatelessWidget {
  const PosterSection({super.key});

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
              return Center(
                child: SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [context.colors.shadow],
                    ),
                    child: PosterView(
                      design: design,
                      selected: state.selected,
                      interactive: true,
                      showGuide: state.showGuide,
                      removing: state.removingBackground,
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
  const UndoSection({super.key});

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
            const SizedBox(height: 10),
            AppButton(
              label: element.photo ? '✂ Remove Background' : '✓ Background removed',
              ghost: true,
              expand: true,
              onPressed: element.photo ? cubit.removeBackground : null,
            ),
            UploadButton(
              label: '⬆ Replace from gallery',
              onTap: () => cubit.pickImage(ImageSlot.selectedOrNew),
            ),
            const FieldLabel('Change image'),
            _EmojiStrip(selected: element.imageBytes == null ? element.emoji : null, onTap: cubit.addEmoji),
          ],
          if (element.kind != ElementKind.text) ...[
            const FieldLabel('Size'),
            Slider(
              min: 8,
              max: 90,
              value: element.w.clamp(8.0, 90.0).toDouble(),
              onChangeStart: (_) => cubit.beginLive(),
              onChanged: cubit.setWidth,
              onChangeEnd: (_) => cubit.endLive(),
            ),
          ],
          const FieldLabel('Rotate'),
          Slider(
            min: -180,
            max: 180,
            value: element.rotation.clamp(-180.0, 180.0).toDouble(),
            onChangeStart: (_) => cubit.beginLive(),
            onChanged: cubit.setRotation,
            onChangeEnd: (_) => cubit.endLive(),
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
      buildWhen: (previous, current) => previous.formTick != current.formTick,
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
                      label: state.updatingPublished ? 'Update' : 'Publish',
                      onPressed: cubit.publish,
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
    final fonts = Catalog.fonts.contains(font) ? Catalog.fonts : [font, ...Catalog.fonts];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: font,
          isExpanded: true,
          isDense: true,
          dropdownColor: colors.card,
          style: poppins(colors),
          items: [
            for (final name in fonts)
              DropdownMenuItem(
                value: name,
                child: Text(name, style: GoogleFonts.getFont(name, fontSize: 14, color: colors.text)),
              ),
          ],
          onChanged: (value) {
            if (value != null) context.read<CreatorCubit>().setFont(value);
          },
        ),
      ),
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
