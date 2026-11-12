import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/poster.dart';
import 'package:mideas_touch_creator/src/theme.dart';
import 'package:mideas_touch_creator/src/ui.dart';

/// Shows the flattened template image when available (preferred for My designs).
class DesignPreviewThumb extends StatelessWidget {
  const DesignPreviewThumb({
    super.key,
    required this.design,
    this.fit = BoxFit.cover,
  });

  final Design design;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final Uint8List? preview = design.previewImage;
    if (preview != null && preview.isNotEmpty) {
      return Image.memory(
        preview,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    return PosterView(design: design, selected: -1, interactive: false);
  }
}

class MyDesignsScreen extends StatelessWidget {
  const MyDesignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: const SafeArea(
        child: Column(
          children: [
            StudioHeader(),
            FilterSwitch(),
            Expanded(child: _DesignList()),
            ViewSwitch(),
          ],
        ),
      ),
    );
  }
}

class _DesignList extends StatelessWidget {
  const _DesignList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) =>
          previous.designs != current.designs ||
          previous.filter != current.filter ||
          previous.publishing != current.publishing,
      builder: (context, state) {
        final designs = state.visibleDesigns;
        if (designs.isEmpty) {
          return ListView(
            children: [
              EmptyCard(
                title: state.filter == DesignFilter.drafts
                    ? 'No drafts'
                    : state.filter == DesignFilter.published
                        ? 'No published designs'
                        : 'No designs yet',
                message: state.filter == DesignFilter.published
                    ? 'Templates published in the last day will appear here.'
                    : 'Designs you save or publish will appear here.',
                action: 'Create design',
                onAction: () => context.read<CreatorCubit>().newDesign(),
              ),
            ],
          );
        }
        final colors = context.colors;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: designs.length,
          itemBuilder: (context, index) {
            final design = designs[index];
            final published = design.status == DesignStatus.published;
            final cubit = context.read<CreatorCubit>();
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [colors.shadow],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 90,
                      child: DesignPreviewThumb(design: design),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(design.name, style: poppins(colors, weight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            PillTag(design.category),
                            PillTag(
                              design.status,
                              background: published ? const Color(0xFF1EED07) : null,
                              foreground: published ? const Color(0xFF0B3300) : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(design.savedAt, style: poppins(colors, size: 12, color: colors.muted)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (published)
                              AppButton(
                                label: 'View',
                                ghost: true,
                                small: true,
                                onPressed: () => showPublishedDesignViewer(context, design),
                              )
                            else
                              AppButton(
                                label: 'Edit',
                                ghost: true,
                                small: true,
                                onPressed: () => cubit.editDesign(design.id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> showPublishedDesignViewer(BuildContext context, Design design) {
  final colors = context.colors;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: colors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        design.name,
                        style: poppins(colors, weight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icon(Icons.close, color: colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PillTag(design.category),
                    const PillTag(
                      DesignStatus.published,
                      background: Color(0xFF1EED07),
                      foreground: Color(0xFF0B3300),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [colors.shadow],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: DesignPreviewThumb(design: design, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (design.savedAt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    design.savedAt,
                    style: poppins(colors, size: 12, color: colors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                AppButton(
                  label: 'Close',
                  ghost: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PublishedScreen extends StatelessWidget {
  const PublishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const StudioHeader(),
            Expanded(
              child: BlocBuilder<CreatorCubit, CreatorState>(
                buildWhen: (previous, current) => previous.publishedDesign != current.publishedDesign,
                builder: (context, state) {
                  final design = state.publishedDesign;
                  if (design == null) return const SizedBox.shrink();
                  final cubit = context.read<CreatorCubit>();
                  return ListView(
                    children: [
                      EmptyCard(
                        dashed: false,
                        title: 'Design published 🎉',
                        message: '“${design.name}” is now live for customers.',
                        action: 'Create another design',
                        onAction: cubit.newDesign,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FractionallySizedBox(
                            widthFactor: 0.52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [colors.shadow],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: DesignPreviewThumb(design: design),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: GestureDetector(
                          onTap: cubit.openMine,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text('View my designs', style: poppins(colors, color: colors.muted)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const ViewSwitch(),
          ],
        ),
      ),
    );
  }
}
