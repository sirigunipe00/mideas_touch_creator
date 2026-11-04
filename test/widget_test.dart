import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mideas_touch_creator/main.dart';
import 'package:mideas_touch_creator/src/creator_cubit.dart';
import 'package:mideas_touch_creator/src/models.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('registration screen matches the creator studio', (tester) async {
    await tester.pumpWidget(const CreatorApp());
    expect(find.text('Create Creator Account'), findsOneWidget);
    expect(find.text('This app is only for Midas’s Touch creators.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('splash')));
    await tester.pump();
    expect(find.text('Create Creator Account'), findsOneWidget);
  });

  test('drafts and publish follow the studio rules', () async {
    final cubit = CreatorCubit()..dismissSplash();
    cubit
      ..setName('Tayyab')
      ..setEmail('tayyab@example.com')
      ..setPassword('secret1')
      ..setAgreed(true)
      ..submitAuth();

    expect(cubit.state.user?.name, 'Tayyab');
    expect(cubit.state.view, StudioView.create);
    expect(cubit.state.current, isNotNull);

    cubit.publish();
    expect(cubit.state.toastMessage, 'Add a design name to publish');
    expect(cubit.state.designs, isEmpty);

    cubit.saveDraft();
    expect(cubit.state.designs.single.name, 'Untitled design');
    expect(cubit.state.designs.single.status, DesignStatus.draft);
    expect(cubit.state.view, StudioView.mine);
    expect(cubit.state.filter, DesignFilter.drafts);

    cubit.setDesignName('Diwali Sale');
    cubit.publish();
    expect(cubit.state.view, StudioView.published);
    expect(cubit.state.designs.single.status, DesignStatus.published);
    expect(cubit.state.publishedDesign?.name, 'Diwali Sale');

    final headline = cubit.state.current!.elements.first.text;
    cubit.setHeadline('Hello sale');
    expect(cubit.state.current!.elements.first.text, 'Hello sale');
    cubit.undo();
    expect(cubit.state.current!.elements.first.text, headline);

    await cubit.close();
  });
}
