import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // GuestIdentityStore reads SharedPreferences, which has no platform
  // implementation under the widget tester. Without this the identity silently
  // fails to load and the "back into your room" path is never exercised.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('landing offers both ways into a room', (tester) async {
    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();

    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(
      find.text('WhatsApp is where you talk. Gather is where you decide.'),
      findsOneWidget,
    );
  });

  testWidgets('creating a room lands you in it as the organizer', (
    tester,
  ) async {
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
    expect(find.textContaining('NOW'), findsWidgets);
  });

  testWidgets('room type cards are all the same height', (tester) async {
    // A real phone width: the cards only wrap at this size, which is the whole
    // point of the check. A wide test viewport would hide the bug.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();

    // "Movie night" wraps to two lines where the other labels do not, so the
    // cards are only uniform if the row stretches them to a shared height.
    Rect cardFor(String label) => tester.getRect(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );

    final cards = ['Meetup', 'Trip', 'Movie night'].map(cardFor).toList();
    for (final card in cards) {
      expect(card.height, cards.first.height);
      expect(card.top, cards.first.top);
      expect(card.bottom, cards.first.bottom);
    }
  });

  testWidgets('organizer can end the event once the plan is done', (
    tester,
  ) async {
    // A tall viewport so the whole organizer sheet is laid out at once. The
    // alternative is driving a draggable bottom sheet with scroll gestures,
    // which tests the sheet's drag physics rather than the end-event flow.
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Friday film club');
    await tester.tap(find.text('Movie night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create room'));
    await tester.pumpAndSettle();

    // The room seeds five steps, so four advances reach the last one.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Move to next step'));
      await tester.pumpAndSettle();
    }

    // On the final step the primary action becomes completing the plan.
    await tester.tap(find.text('Complete plan'));
    await tester.pumpAndSettle();

    // Ending the event is offered once the plan is complete.
    expect(find.text('End the event'), findsWidgets);

    // Ending is destructive, so it is confirmed rather than immediate. The
    // button lives in the sheet; the same label also sits on the Now tab
    // behind it, so the tap is scoped to the sheet.
    await tester.tap(
      find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text('End the event'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('End the event?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'End the event'));
    await tester.pumpAndSettle();

    // The room reads as finished and the offer is gone.
    expect(find.text('Event ended'), findsOneWidget);
    expect(find.text('End the event'), findsNothing);
  });

  testWidgets('leaving a room offers a way back into it', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();
    // Nothing to return to before a room has been visited.
    expect(find.textContaining('Back into room'), findsNothing);

    await tester.tap(find.text('Create a room'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Friday film club');
    await tester.tap(find.text('Movie night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create room'));
    await tester.pumpAndSettle();

    // Back out of the room and onto the landing screen.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The landing screen must offer a way back in, not just a blank code
    // field. This is the whole point of remembering the last room.
    final back = find.textContaining('Back into room');
    expect(back, findsOneWidget);

    // And following it gets you back into the same room.
    await tester.tap(back);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join room'));
    await tester.pumpAndSettle();

    expect(find.text('Friday film club'), findsWidgets);
    expect(find.text('Snacks and settling in'), findsWidgets);
  });

  testWidgets('the landing screen shows one wordmark', (tester) async {
    await tester.pumpWidget(const GatherApp());
    await tester.pumpAndSettle();

    expect(find.text('Gather'), findsOneWidget);
  });
}
