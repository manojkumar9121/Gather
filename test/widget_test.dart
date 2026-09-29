import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/app.dart';

void main() {
  testWidgets('landing offers both ways into a room', (tester) async {
    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();

    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text('WhatsApp is where you talk. Gather is where you decide.'),
        findsOneWidget);
  });

  testWidgets('creating a room lands you in it as the organizer',
      (tester) async {
    // A tall viewport so the whole create form is laid out. Scrolling to find
    // the submit button would test the ListView, not the flow.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();

    // The first field on the create screen is the room name.
    await tester.enterText(find.byType(TextField).first, 'Friday film club');
    await tester.tap(find.text('Movie night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create room'));
    await tester.pumpAndSettle();

    // The organizer lands on the room with the Now tab selected.
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Snacks and settling in'), findsWidgets);
    expect(find.text('HAPPENING NOW'), findsOneWidget);
  });
}
