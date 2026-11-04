import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/theme.dart';
import 'package:mideas_touch_creator/src/ui.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _coins;
  late final AnimationController _glow;
  late final AnimationController _logo;
  late final AnimationController _dots;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _coins = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) context.read<CreatorCubit>().dismissSplash();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    _coins.dispose();
    _glow.dispose();
    _logo.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        key: const Key('splash'),
        onTap: () => context.read<CreatorCubit>().dismissSplash(),
        child: ColoredBox(
          color: colors.bg,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) {
                  final scale = 1 + (0.25 * _glow.value);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 1 - (0.3 * _glow.value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x73EFBF05), Color(0x00EFBF05)],
                      stops: [0, 0.7],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _coins,
                builder: (context, _) {
                  final time = _coins.value * 4;
                  return Stack(
                    children: [
                      for (var i = 0; i < 14; i++) _fallingCoin(i, time),
                    ],
                  );
                },
              ),
              AnimatedBuilder(
                animation: _logo,
                builder: (context, child) {
                  final t = const Cubic(0.2, 1.4, 0.4, 1).transform(_logo.value.clamp(0, 1));
                  return Opacity(
                    opacity: _logo.value.clamp(0, 1),
                    child: Transform.rotate(
                      angle: -8 * math.pi / 180 * (1 - t),
                      child: Transform.scale(scale: 0.3 + (0.7 * t), child: child),
                    ),
                  );
                },
                child: const LogoImage(height: 150),
              ),
              Positioned(
                bottom: 60,
                child: AnimatedBuilder(
                  animation: _dots,
                  builder: (context, _) {
                    return Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _dot(i),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallingCoin(int index, double time) {
    final delay = (index % 7) * 0.28;
    final duration = 1.8 + (index % 4) * 0.35;
    var progress = (time - delay) / duration;
    progress -= progress.floorToDouble();
    final left = ((index * 37 + 8) % 92) / 100;
    return Align(
      alignment: Alignment((left * 2) - 1, -1),
      child: Transform.translate(
        offset: Offset(0, -40 + (progress * 1000)),
        child: Transform.rotate(
          angle: progress * math.pi * 2,
          child: const CoinIcon(size: 26),
        ),
      ),
    );
  }

  Widget _dot(int index) {
    var shifted = (_dots.value - (index * 0.15)) % 1;
    if (shifted < 0) shifted += 1;
    final wave = shifted < 0.5 ? shifted / 0.5 : (1 - shifted) / 0.5;
    return Transform.translate(
      offset: Offset(0, -8 * wave),
      child: Opacity(
        opacity: 1 - (0.6 * wave),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
