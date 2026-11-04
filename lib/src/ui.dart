import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/theme.dart';

class LogoImage extends StatelessWidget {
  const LogoImage({required this.height, this.forceLight = false, super.key});

  final double height;
  final bool forceLight;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark && !forceLight;
    return Image.asset(
      dark ? 'assets/logo_dark.png' : 'assets/logo_light.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _CoinPainter(),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final rect = Rect.fromCircle(center: const Offset(12, 12), radius: 11);
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A0), Color(0xFFFFC928), Color(0xFFC88700)],
        stops: [0, 0.45, 1],
      ).createShader(rect);
    canvas.drawCircle(const Offset(12, 12), 11, fill);
    canvas.drawCircle(
      const Offset(12, 12),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFA87000),
    );
    canvas.drawCircle(
      const Offset(12, 12),
      7.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFB37A00),
    );
    final star = Path()
      ..moveTo(12, 7.2)
      ..relativeLineTo(1.4, 3)
      ..relativeLineTo(3.3, 0.4)
      ..relativeLineTo(-2.4, 2.3)
      ..relativeLineTo(0.6, 3.2)
      ..relativeLineTo(-2.9, -1.6)
      ..relativeLineTo(-2.9, 1.6)
      ..relativeLineTo(0.6, -3.2)
      ..relativeLineTo(-2.4, -2.3)
      ..relativeLineTo(3.3, -0.4)
      ..close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF3B0));
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFB37A00),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

TextStyle poppins(
  AppColors colors, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.45,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color ?? colors.text,
    height: height,
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(text, style: poppins(context.colors, size: 11, color: context.colors.muted, height: 1.2)),
    );
  }
}

class SyncedField extends StatefulWidget {
  const SyncedField({
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.obscure = false,
    this.keyboard,
    this.live = true,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboard;
  final bool live;
  final TextAlign textAlign;

  @override
  State<SyncedField> createState() => _SyncedFieldState();
}

class _SyncedFieldState extends State<SyncedField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!_focus.hasFocus && !widget.live) widget.onChanged(_controller.text);
  }

  @override
  void didUpdateWidget(SyncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.line),
    );
    return TextField(
      controller: _controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: widget.obscure ? 1 : widget.maxLines,
      textAlign: widget.textAlign,
      keyboardType: widget.maxLines > 1 ? TextInputType.multiline : widget.keyboard,
      cursorColor: colors.primaryDark,
      style: poppins(colors),
      onChanged: widget.live ? widget.onChanged : null,
      onSubmitted: widget.live ? null : widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: poppins(colors, color: colors.muted),
        filled: true,
        fillColor: colors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.ghost = false,
    this.danger = false,
    this.expand = false,
    this.small = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool danger;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color background;
    final Color foreground;
    if (danger) {
      background = const Color(0xFFED0707);
      foreground = Colors.white;
    } else if (ghost) {
      background = colors.primaryLight2;
      foreground = colors.text;
    } else {
      background = colors.primary;
      foreground = colors.primaryText;
    }
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          alignment: Alignment.center,
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
              : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(small ? 10 : 14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: poppins(colors, size: small ? 12 : 14, weight: FontWeight.w600, color: foreground, height: 1.2),
          ),
        ),
      ),
    );
  }
}

class SquareButton extends StatelessWidget {
  const SquareButton({
    required this.child,
    required this.onTap,
    this.active = false,
    this.tooltip,
    this.dimmed = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.primaryLight2 : colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? colors.primary : colors.line, width: active ? 1.4 : 1),
          ),
          child: child,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    required this.labels,
    required this.index,
    required this.onChanged,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i == index ? colors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: poppins(
                            colors,
                            size: 13,
                            weight: i == index ? FontWeight.w600 : FontWeight.w400,
                            color: i == index ? colors.primaryText : colors.text,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChoiceChips extends StatelessWidget {
  const ChoiceChips({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          GestureDetector(
            onTap: () => onSelected(label),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: label == selected ? colors.primary : colors.card,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: label == selected ? colors.primary : colors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  label,
                  style: poppins(
                    colors,
                    size: 13,
                    color: label == selected ? colors.primaryText : colors.text,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PillTag extends StatelessWidget {
  const PillTag(this.text, {this.background, this.foreground, super.key});

  final String text;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colors.primaryLight2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
        child: Text(
          text,
          style: poppins(colors, size: 11, color: foreground ?? colors.text, height: 1.3),
        ),
      ),
    );
  }
}

class UploadButton extends StatelessWidget {
  const UploadButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colors.primaryLight2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label, style: poppins(colors, size: 13, weight: FontWeight.w600, height: 1.2)),
        ),
      ),
    );
  }
}

class StudioHeader extends StatelessWidget {
  const StudioHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const LogoImage(height: 44),
          const SizedBox(width: 8),
          const PillTag('Creator'),
          const Spacer(),
          SquareButton(
            onTap: () => context.read<CreatorCubit>().toggleTheme(currentlyDark: dark),
            child: Text(dark ? '☀' : '☾', style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          SquareButton(
            tooltip: 'Log out',
            onTap: () => context.read<CreatorCubit>().logout(),
            child: Text('⎋', style: poppins(context.colors, size: 16, height: 1)),
          ),
        ],
      ),
    );
  }
}

class ViewSwitch extends StatelessWidget {
  const ViewSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.view != current.view || previous.designs.length != current.designs.length,
      builder: (context, state) {
        final index = state.view == StudioView.create
            ? 0
            : state.view == StudioView.mine
                ? 1
                : -1;
        return SegmentedControl(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          labels: ['Create', 'My designs (${state.designs.length})'],
          index: index,
          onChanged: (value) {
            final cubit = context.read<CreatorCubit>();
            if (value == 0) {
              cubit.newDesign();
            } else {
              cubit.openMine();
            }
          },
        );
      },
    );
  }
}

class FilterSwitch extends StatelessWidget {
  const FilterSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.filter != current.filter,
      builder: (context, state) {
        return SegmentedControl(
          labels: const ['All', 'Published', 'Drafts'],
          index: state.filter.index,
          onChanged: (value) => context.read<CreatorCubit>().setFilter(DesignFilter.values[value]),
        );
      },
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    required this.title,
    required this.message,
    this.action,
    this.onAction,
    this.dashed = true,
    this.child,
    super.key,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool dashed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: dashed ? null : Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          if (child != null) child!,
          Text(title, textAlign: TextAlign.center, style: poppins(colors, size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: poppins(colors, color: colors.muted)),
          if (action != null) ...[
            const SizedBox(height: 12),
            AppButton(label: action!, onPressed: onAction),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: dashed
          ? CustomPaint(
              foregroundPainter: _DashedRRectPainter(color: colors.line, radius: 20),
              child: card,
            )
          : card,
    );
  }
}

Future<Color?> showColorPicker(BuildContext context, Color current) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorDialog(color: current),
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.color});

  final Color color;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _hsv.toColor();
    return Dialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.line),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Hue', style: poppins(colors, size: 11, color: colors.muted)),
            Slider(
              min: 0,
              max: 360,
              value: _hsv.hue,
              onChanged: (value) => setState(() => _hsv = _hsv.withHue(value)),
            ),
            Text('Saturation', style: poppins(colors, size: 11, color: colors.muted)),
            Slider(
              min: 0,
              max: 1,
              value: _hsv.saturation,
              onChanged: (value) => setState(() => _hsv = _hsv.withSaturation(value)),
            ),
            Text('Brightness', style: poppins(colors, size: 11, color: colors.muted)),
            Slider(
              min: 0,
              max: 1,
              value: _hsv.value,
              onChanged: (value) => setState(() => _hsv = _hsv.withValue(value)),
            ),
            const SizedBox(height: 8),
            AppButton(label: 'Use this colour', onPressed: () => Navigator.pop(context, color)),
          ],
        ),
      ),
    );
  }
}

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.language != current.language,
      builder: (context, state) {
        return DecoratedBox(
          decoration: BoxDecoration(color: colors.primaryLight, borderRadius: BorderRadius.circular(99)),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _lang(context, 'en', 'English', state.language == 'en'),
                _lang(context, 'hi', 'हिन्दी', state.language == 'hi'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lang(BuildContext context, String code, String label, bool on) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => context.read<CreatorCubit>().setLanguage(code),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: on ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            label,
            style: poppins(
              colors,
              size: 12,
              weight: on ? FontWeight.w600 : FontWeight.w400,
              color: on ? colors.primaryText : colors.text,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return SquareButton(
      onTap: () => context.read<CreatorCubit>().toggleTheme(currentlyDark: dark),
      child: Text(dark ? '☀' : '☾', style: const TextStyle(fontSize: 18)),
    );
  }
}

double cssAngle(double degrees) => (degrees - 90) * math.pi / 180;

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) => oldDelegate.color != color;
}
