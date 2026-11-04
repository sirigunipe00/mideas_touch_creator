import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/create_screen.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/designs_screen.dart';
import 'package:mideas_touch_creator/src/login_screen.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/splash.dart';
import 'package:mideas_touch_creator/src/theme.dart';
import 'package:mideas_touch_creator/src/ui.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  String? _message;
  bool _show = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreatorCubit, CreatorState>(
      listenWhen: (previous, current) => previous.toastTick != current.toastTick,
      listener: (context, state) {
        _timer?.cancel();
        setState(() {
          _message = state.toastMessage;
          _show = true;
        });
        _timer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _show = false);
        });
      },
      child: Stack(
        children: [
          const Positioned.fill(child: _StudioPage()),
          const Positioned.fill(child: _SplashSlot()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 84,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _show ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedSlide(
                  offset: _show ? Offset.zero : const Offset(0, 0.4),
                  duration: const Duration(milliseconds: 250),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2410),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          _message ?? '',
                          textAlign: TextAlign.center,
                          style: poppins(
                            context.colors,
                            size: 13,
                            color: const Color(0xFFFCF4D3),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioPage extends StatelessWidget {
  const _StudioPage();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.user != current.user || previous.view != current.view,
      builder: (context, state) {
        if (state.user == null) return const LoginScreen();
        switch (state.view) {
          case StudioView.create:
            return const CreateScreen();
          case StudioView.mine:
            return const MyDesignsScreen();
          case StudioView.published:
            return const PublishedScreen();
        }
      },
    );
  }
}

class _SplashSlot extends StatelessWidget {
  const _SplashSlot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorCubit, CreatorState>(
      buildWhen: (previous, current) => previous.splash != current.splash,
      builder: (context, state) {
        if (!state.splash) return const SizedBox.shrink();
        return const SplashView();
      },
    );
  }
}
