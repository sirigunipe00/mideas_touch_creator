import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mideas_touch_creator/src/auth_repository.dart';
import 'package:mideas_touch_creator/src/create_screen.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/login_screen.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/template_repository.dart';
import 'package:mideas_touch_creator/src/theme.dart';

class _MemoryTemplates implements TemplateRepository {
  final saved = <Design>[];
  int nextId = 100;
  int nextDraftId = 1;
  String? userId;

  @override
  void setAuth({String? accessToken, String? userId, String? email}) {
    this.userId = userId;
  }

  @override
  Future<int> publish(Design design, {required String authorName, Uint8List? poster}) async {
    saved.add(design);
    return design.remoteId ?? nextId++;
  }

  @override
  Future<int> saveDraft(Design design, {required String authorName, Uint8List? poster}) async {
    return design.draftId ?? nextDraftId++;
  }

  @override
  Future<List<Design>> fetchDrafts() async => [];

  @override
  Future<List<Design>> fetchPublished({Duration within = const Duration(days: 1)}) async => [];

  @override
  Future<void> deleteDraft(int draftId) async {}

  @override
  void close() {}
}

class _MemoryAuth implements AuthRepository {
  AuthSession? session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    session = AuthSession(
      user: StudioUser(id: 'user-1', name: name, email: email),
      accessToken: 'token',
      refreshToken: 'refresh',
    );
    return session!;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    session = AuthSession(
      user: StudioUser(id: 'user-1', name: 'Creator', email: email),
      accessToken: 'token',
      refreshToken: 'refresh',
    );
    return session!;
  }

  @override
  Future<void> logout() async {
    session = null;
  }

  @override
  void close() {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('studio shows login after splash when logged out', (tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => CreatorCubit(templates: _MemoryTemplates(), auth: _MemoryAuth()),
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) {
              return BlocBuilder<CreatorCubit, CreatorState>(
                builder: (context, state) {
                  if (state.splash) {
                    return GestureDetector(
                      key: const Key('splash'),
                      onTap: () => context.read<CreatorCubit>().dismissSplash(),
                      child: const SizedBox.expand(),
                    );
                  }
                  if (state.user == null) return const LoginScreen();
                  return const CreateScreen();
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('splash')));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Create Creator Account'), findsOneWidget);
  });

  test('drafts and publish follow the studio rules', () async {
    final templates = _MemoryTemplates();
    final auth = _MemoryAuth();
    final cubit = CreatorCubit(templates: templates, auth: auth)..dismissSplash();
    await cubit.submitAuth();
    expect(cubit.state.toastMessage, 'Enter your full name');

    cubit
      ..setName('Tayyab')
      ..setEmail('tayyab@example.com')
      ..setPassword('secret12');
    await cubit.submitAuth();

    expect(cubit.state.user?.name, 'Tayyab');
    expect(cubit.state.user?.id, 'user-1');
    expect(templates.userId, 'user-1');
    expect(cubit.state.view, StudioView.create);
    expect(cubit.state.current, isNotNull);

    await cubit.publish();
    expect(cubit.state.toastMessage, 'Add a design name to publish');
    expect(cubit.state.designs, isEmpty);
    expect(templates.saved, isEmpty);

    cubit.saveDraft();
    expect(cubit.state.designs.single.name, 'Untitled design');
    expect(cubit.state.designs.single.status, DesignStatus.draft);
    expect(cubit.state.view, StudioView.mine);
    expect(cubit.state.filter, DesignFilter.drafts);

    cubit.setDesignName('Diwali Sale');
    await cubit.publish(poster: Uint8List.fromList(const [1, 2, 3, 4]));
    expect(cubit.state.view, StudioView.published);
    expect(cubit.state.designs.single.status, DesignStatus.published);
    expect(cubit.state.publishedDesign?.name, 'Diwali Sale');
    expect(cubit.state.publishedDesign?.remoteId, 100);
    expect(templates.saved.single.name, 'Diwali Sale');

    final headline = cubit.state.current!.elements.first.text;
    cubit.setHeadline('Hello sale');
    expect(cubit.state.current!.elements.first.text, 'Hello sale');
    cubit.undo();
    expect(cubit.state.current!.elements.first.text, headline);

    await cubit.close();
  });
}
