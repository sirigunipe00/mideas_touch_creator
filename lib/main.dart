import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/studio_screen.dart';
import 'package:mideas_touch_creator/src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CreatorApp());
}

class CreatorApp extends StatelessWidget {
  const CreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreatorCubit(),
      child: MaterialApp(
        title: 'Midas’s Touch Creator',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          return BlocBuilder<CreatorCubit, CreatorState>(
            buildWhen: (previous, current) => previous.themeMode != current.themeMode,
            builder: (context, state) {
              final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
              final dark = state.themeMode == ThemeMode.dark || (state.themeMode == ThemeMode.system && platformDark);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                child: Theme(
                  data: buildTheme(dark ? Brightness.dark : Brightness.light),
                  child: AppPalette(
                    colors: dark ? AppColors.dark : AppColors.light,
                    isDark: dark,
                    child: PhoneFrame(child: child ?? const SizedBox.shrink()),
                  ),
                ),
              );
            },
          );
        },
        home: const StudioScreen(),
      ),
    );
  }
}

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.backdrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 500;
          if (!wide) return child;
          final height = math.min(constraints.maxHeight - 32, 860.0);
          final width = math.min(430.0, constraints.maxWidth - 32);
          return Center(
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(38),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: ColoredBox(color: colors.bg, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
