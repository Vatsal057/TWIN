/// The illustrated avatar set, in picker order: the 50 playful faces
/// first (a41..a90: expressions, hobbies, occasions, light costume),
/// then the 16 goofy ones (a25..a40: frog hats, shark hoodies, traffic
/// cones), then the 24 plain portraits (a1..a24).
///
/// A player's choice is stored as one of these IDs; the artwork lives in
/// `assets/avatars/avatar_<n>.png`. Keeping the choice as an ID (not an
/// image) is what lets the same face render everywhere: Settings picker,
/// home rows, game header, chat and result screens, including on the
/// other player's device via the room (see Room.playerAvatars).
class AppAvatars {
  AppAvatars._();

  static const List<String> ids = [
    'a41',
    'a42',
    'a43',
    'a44',
    'a45',
    'a46',
    'a47',
    'a48',
    'a49',
    'a50',
    'a51',
    'a52',
    'a53',
    'a54',
    'a55',
    'a56',
    'a57',
    'a58',
    'a59',
    'a60',
    'a61',
    'a62',
    'a63',
    'a64',
    'a65',
    'a66',
    'a67',
    'a68',
    'a69',
    'a70',
    'a71',
    'a72',
    'a73',
    'a74',
    'a75',
    'a76',
    'a77',
    'a78',
    'a79',
    'a80',
    'a81',
    'a82',
    'a83',
    'a84',
    'a85',
    'a86',
    'a87',
    'a88',
    'a89',
    'a90',
    'a25',
    'a26',
    'a27',
    'a28',
    'a29',
    'a30',
    'a31',
    'a32',
    'a33',
    'a34',
    'a35',
    'a36',
    'a37',
    'a38',
    'a39',
    'a40',
    'a1',
    'a2',
    'a3',
    'a4',
    'a5',
    'a6',
    'a7',
    'a8',
    'a9',
    'a10',
    'a11',
    'a12',
    'a13',
    'a14',
    'a15',
    'a16',
    'a17',
    'a18',
    'a19',
    'a20',
    'a21',
    'a22',
    'a23',
    'a24',
  ];

  static const String fallback = 'a41';

  static bool isValid(String? id) => id != null && ids.contains(id);

  static String assetFor(String id) =>
      'assets/avatars/avatar_${id.substring(1)}.png';

  /// Deterministic avatar for a display name, so the same friend always
  /// shows the same face. The demo friends keep fixed characters: Ivy
  /// gets the cat ears, Leo the robot, Zoe the bubble gum, Maya the
  /// shark hoodie, Sam the tiny party hat.
  static String forName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty || lower == 'you') return fallback;
    if (lower.contains('ivy')) return 'a28';
    if (lower.contains('leo')) return 'a30';
    if (lower.contains('zoe')) return 'a31';
    if (lower.contains('maya')) return 'a26';
    if (lower.contains('sam')) return 'a37';
    var hash = 0;
    for (final unit in lower.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return ids[hash % ids.length];
  }

  /// Migration from the old Settings picker, which stored an emoji.
  static String fromLegacyEmoji(String emoji) {
    switch (emoji) {
      case '😎':
        return 'a40';
      case '🤠':
        return 'a36';
      case '👻':
        return 'a29';
      case '🦊':
        return 'a28';
      case '🐙':
        return 'a33';
      case '🌙':
        return 'a35';
      case '🔥':
        return 'a26';
      default:
        return fallback;
    }
  }
}
