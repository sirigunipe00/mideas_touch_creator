import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/catalog.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/theme.dart';
import 'package:mideas_touch_creator/src/ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: BlocBuilder<CreatorCubit, CreatorState>(
          buildWhen: (previous, current) =>
              previous.authTab != current.authTab ||
              previous.language != current.language ||
              previous.agreed != current.agreed ||
              previous.formTick != current.formTick,
          builder: (context, state) {
            final cubit = context.read<CreatorCubit>();
            final register = state.authTab == AuthTab.register;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 46, 24, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      transform: GradientRotation(cssAngle(160)),
                      colors: const [Color(0xFFEFBF05), Color(0xFFF6DA6F)],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          LanguageToggle(),
                          Spacer(),
                          ThemeToggle(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const LogoImage(height: 84, forceLight: true),
                      const SizedBox(height: 6),
                      Text(
                        Catalog.tagline(state.language),
                        textAlign: TextAlign.center,
                        style: poppins(colors, weight: FontWeight.w600, color: AppColors.ink, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      SegmentedControl(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        labels: const ['Login', 'Register'],
                        index: register ? 1 : 0,
                        onChanged: (index) => cubit.setAuthTab(index == 0 ? AuthTab.login : AuthTab.register),
                      ),
                      if (register) ...[
                        SyncedField(
                          key: const Key('full-name'),
                          value: state.name,
                          hint: 'Full name',
                          onChanged: cubit.setName,
                        ),
                        const SizedBox(height: 10),
                      ],
                      SyncedField(
                        key: const Key('email'),
                        value: state.email,
                        hint: 'Email',
                        keyboard: TextInputType.emailAddress,
                        onChanged: cubit.setEmail,
                      ),
                      const SizedBox(height: 10),
                      SyncedField(
                        key: const Key('password'),
                        value: state.password,
                        hint: 'Password',
                        obscure: true,
                        onChanged: cubit.setPassword,
                      ),
                      if (register)
                        GestureDetector(
                          onTap: () => cubit.setAgreed(!state.agreed),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: state.agreed ? colors.primary : colors.card,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: state.agreed ? colors.primary : colors.line),
                                  ),
                                  child: state.agreed
                                      ? Icon(Icons.check, size: 14, color: colors.primaryText)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'I will upload only original designs I have the rights to',
                                    style: poppins(colors, size: 12, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: register ? 'Create Creator Account' : 'Login',
                        expand: true,
                        onPressed: cubit.submitAuth,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: cubit.forgotPassword,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Forgot Password',
                            style: poppins(colors, color: colors.muted),
                          ),
                        ),
                      ),
                      Text(
                        'This app is only for Midas’s Touch creators.',
                        textAlign: TextAlign.center,
                        style: poppins(colors, size: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
