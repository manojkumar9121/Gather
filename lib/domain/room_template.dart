import 'models.dart';

/// Per-type config. This is a constant map on purpose: templates are config,
/// not architecture, and there is no plugin or module registry.
class RoomTemplate {
  const RoomTemplate({
    required this.itemLabel,
    required this.itemKind,
    required this.itemVerb,
    required this.checkInLabel,
    required this.autoCheckInOnQr,
    required this.agendaLabel,
    required this.agendaHint,
    required this.showChecklist,
    required this.showExpenses,
    required this.defaultSteps,
  });

  /// What attendees call the thing they post. "Questions" / "Stop ideas" /
  /// "Movie picks".
  final String itemLabel;
  final ItemKind itemKind;

  /// Imperative form, used on the post button.
  final String itemVerb;

  final String checkInLabel;

  /// In meetup rooms the QR sits at the door, so scanning it is the act of
  /// arriving. Other types use the button.
  final bool autoCheckInOnQr;

  final String agendaLabel;
  final String agendaHint;
  final bool showChecklist;
  final bool showExpenses;

  /// Seeded into a new room so "where are we?" has an answer immediately
  /// instead of an empty state.
  final List<String> defaultSteps;
}

const Map<RoomType, RoomTemplate> kRoomTemplates = {
  RoomType.meetup: RoomTemplate(
    itemLabel: 'Questions',
    itemKind: ItemKind.question,
    itemVerb: 'Ask',
    checkInLabel: "I'm here",
    autoCheckInOnQr: true,
    agendaLabel: 'Schedule',
    agendaHint: 'Where the event is right now',
    showChecklist: false,
    showExpenses: false,
    defaultSteps: [
      'Doors open',
      'Welcome',
      'Main event',
      'Q&A',
      'Wrap up',
    ],
  ),
  RoomType.trip: RoomTemplate(
    itemLabel: 'Stop ideas',
    itemKind: ItemKind.stop,
    itemVerb: 'Suggest',
    checkInLabel: "I've arrived",
    autoCheckInOnQr: false,
    agendaLabel: 'Itinerary',
    agendaHint: 'Where the trip is right now',
    showChecklist: true,
    showExpenses: true,
    defaultSteps: [
      'Meet up',
      'Travel',
      'Arrive',
      'Check in',
      'Explore',
    ],
  ),
  RoomType.movie: RoomTemplate(
    itemLabel: 'Movie picks',
    itemKind: ItemKind.suggestion,
    itemVerb: 'Nominate',
    checkInLabel: "I'm here",
    autoCheckInOnQr: false,
    agendaLabel: 'Showtime',
    agendaHint: 'Where movie night is right now',
    showChecklist: true,
    showExpenses: true,
    defaultSteps: [
      'Snacks and settling in',
      'Trailers',
      'Lights down',
      'Credits roll',
      'The debate',
    ],
  ),
};

RoomTemplate templateFor(RoomType type) => kRoomTemplates[type]!;

/// Default check-in expectations per template, used as a starting value for
/// "N of M here" when the organizer has not set their own.
const Map<RoomType, int> kDefaultExpected = {
  RoomType.meetup: 20,
  RoomType.trip: 8,
  RoomType.movie: 6,
};
