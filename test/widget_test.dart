import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/main.dart';
import 'package:mideas_touch_creator/src/create_screen.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/template_repository.dart';

class _MemoryTemplates implements TemplateRepository {
  final saved = <Design>[];
  int nextId = 100;
  int nextDraftId = 1;

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

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('studio skips login and opens the create screen', (tester) async {
    await tester.pumpWidget(const CreatorApp());

    await tester.tap(find.byKey(const Key('splash')));
    await tester.pump();
    expect(find.byType(CreateScreen), findsOneWidget);
    expect(find.text('Create Creator Account'), findsNothing);
  });

  test('drafts and publish follow the studio rules', () async {
    final templates = _MemoryTemplates();
    final cubit = CreatorCubit(templates: templates)..dismissSplash();
    cubit
      ..setName('Tayyab')
      ..setEmail('tayyab@example.com')
      ..setPassword('secret1')
      ..setAgreed(true)
      ..submitAuth();

    expect(cubit.state.user?.name, 'Tayyab');
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
