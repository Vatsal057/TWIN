import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/game_invite.dart';
import '../services/stats_service.dart';
import '../state/app_session.dart';
import 'room_launcher.dart';
import 'views/chat_list_view.dart';
import 'views/history_view.dart';
import 'views/profile_view.dart';
import 'widgets/character_avatar.dart';
import 'widgets/create_room_sheet.dart';
import 'widgets/floating_bottom_bar.dart';
import 'widgets/join_sheet.dart';
import 'widgets/lifetime_stats_sheet.dart';
import 'widgets/reference_brand_mark.dart';
import 'widgets/reference_icons.dart';

const _taglines = [
  'Different words\nbring you closer',
  'Say the same thing',
  'Two minds, one word',
  'No points. Just magic.',
  'Closer every round',
];

/// The footer chip pair shown with each tagline: the two chip
/// words and their colours, rotating on the same index. The first
/// pair is the reference artwork's IDEAS / PEOPLE in its sampled
/// colours; the rest follow their taglines in the same style.
const _chipPairs = [
  ('IDEAS', 'PEOPLE', Color(0xFFCBF56E), Color(0xFFEC715D)),
  ('YOURS', 'MINE', Color(0xFFFFC94D), Color(0xFF5EB1EF)),
  ('MINDS', 'WORD', Color(0xFFB79CFF), Color(0xFF63E6BE)),
  ('POINTS', 'MAGIC', Color(0xFFFFA26B), Color(0xFFE08FFF)),
  ('FAR', 'NEAR', Color(0xFF62DFF5), Color(0xFFFF8FAB)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _taglineIdx = 0;
  MainTab _currentTab = MainTab.play;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _taglineIdx = (_taglineIdx + 1) % _taglines.length);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return ListenableBuilder(
      listenable: session.unread,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: session.palette.bg,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentTab.index,
                children: [
                  _buildPlayTab(context, session),
                  const ChatListView(),
                  const HistoryView(),
                  const ProfileView(),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 24,
                child: Center(
                  child: FloatingBottomBar(
                    currentTab: _currentTab,
                    palette: session.palette,
                    unreadCount: session.unread.totalUnread,
                    profileAvatarId: session.profileAvatarId,
                    profileName: session.displayName,
                    onTabSelected: (tab) => setState(() => _currentTab = tab),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayTab(BuildContext context, AppSession session) {
    final p = session.palette;
    // One fill-height column with spaceBetween: the gaps inside
    // the blocks below are minimums, and whatever height the
    // screen has left over is shared out equally between the
    // blocks, so no single void collects anywhere. On a short
    // screen the column takes its natural height and the page
    // scrolls instead.
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header block: the brand row, plus the offline
                  // notice when the backend fell back
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
          // Top Header Row: "Twin", "SAME? / WORD?" BrandMark, Settings Cog
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Twin',
                        style: GoogleFonts.outfit(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          color: p.text,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => LifetimeStatsSheet.show(context),
                        borderRadius: BorderRadius.circular(8),
                        child: ListenableBuilder(
                          listenable: StatsService.instance,
                          builder: (context, _) {
                            return FutureBuilder<LifetimeStats>(
                              future: StatsService.instance.getStats(),
                              initialData: StatsService.instance.cached,
                              builder: (context, snapshot) {
                                final stats = snapshot.data ?? StatsService.instance.cached;
                                final best = stats?.fastestConvergenceRounds;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      best == null
                                          ? 'Your best: no twinnings yet'
                                          : 'Your best: matched in $best rounds',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: p.muted,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: p.muted,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                ],
              ),

              // Decorative Brand Mark positioned in header, scrolling with content
              const Positioned(
                top: 4,
                right: 0,
                child: IgnorePointer(
                  child: ReferenceBrandMark(),
                ),
              ),
            ],
          ),

          if (session.backendFallbackReason != null) ...[
            const SizedBox(height: 16),
            _OfflineNotice(message: session.backendFallbackReason!),
          ],
                    ],
                  ),

                  // Actions block: Create, Join, and any invites
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

              // Primary actions: Create game (lime) and Join game (navy)
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final config = await CreateRoomSheet.show(context);
                  if (config == null || !context.mounted) return;
                  await RoomLauncher.createAndOpen(
                    context,
                    session,
                    config: config,
                  );
                },
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const ConvergeIcon(size: 46),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create game',
                              style: GoogleFonts.outfit(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: p.onAccent,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Set it up, then send the invite',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: p.onAccent.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: p.onAccent.withValues(alpha: 0.5),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Join game: enter a friend's code
              InkWell(
                onTap: () async {
                  final code = await JoinSheet.show(context);
                  if (code != null && context.mounted) {
                    RoomLauncher.joinAndOpen(context, session, code);
                  }
                },
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: p.accentInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join game',
                              style: GoogleFonts.outfit(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: p.text,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Enter a friend's code",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: p.muted,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),

              // Incoming invites from friends
              _InviteList(session: session),
                      ],
                    ),
                  ),

                  // Guide block: how it works, with the lifetime
                  // stats strip under it
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HowItWorks(),
                        const SizedBox(height: 20),
                        const _StatsStrip(),
                      ],
                    ),
                  ),

                  // Footer block: the rotating tagline in a
                  // fixed-height slot, so rotation never shifts
                  // the layout, then the word chips on their
                  // beaded chain and the indicator dots
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 40,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _taglines[_taglineIdx],
                      key: ValueKey(_taglineIdx),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        color: p.muted,
                        height: 1.8,
                      ),
                    ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),

                  // Word chips joined by the beaded chain, from the
                  // reference artwork: 87x47 chips tilted -12 and
                  // +11 degrees at the corners, the chain a dotted
                  // parabola strung between their centres. The
                  // words and colours rotate with the tagline. The
                  // composition keeps the artwork's own 350 width,
                  // centred: stretched across a wide window the
                  // chain goes sparse and flat and stops looking
                  // like the artwork.
                  Center(
                    child: SizedBox(
                      width: 350,
                      height: 56,
                      child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _BeadChainPainter(color: p.muted)),
                        ),
                        Positioned(
                          left: 6,
                          top: 4,
                          child: Transform.rotate(
                            angle: -12 * math.pi / 180,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _FooterChip(
                                key: ValueKey(_taglineIdx),
                                word: _chipPairs[_taglineIdx].$1,
                                color: _chipPairs[_taglineIdx].$3,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 4,
                          child: Transform.rotate(
                            angle: 11 * math.pi / 180,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _FooterChip(
                                key: ValueKey(_taglineIdx),
                                word: _chipPairs[_taglineIdx].$2,
                                color: _chipPairs[_taglineIdx].$4,
                              ),
                            ),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _taglines.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _taglineIdx ? 16 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == _taglineIdx ? p.accentInk : p.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      }
    }

/// One of the two word chips in the footer: a small sticker in
/// the reference artwork's proportions (87x47, radius 12, the same
/// drop shadow), its word and colour rotating with the tagline.
class _FooterChip extends StatelessWidget {
  const _FooterChip({super.key, required this.word, required this.color});

  final String word;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 87,
      height: 47,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        word,
        softWrap: false,
        style: GoogleFonts.outfit(
          fontSize: 19.5,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: const Color(0xFF151434),
        ),
      ),
    );
  }
}

/// The beaded chain between the footer chips, measured dot by
/// dot from the reference artwork (segmentation of the original
/// image, not a formula): the curve runs close to a parabola but
/// flatter across the top, and the beads sit at radius 2.2 to 2.4
/// rather than one exact size. Each entry is one dot: its
/// position across the span (u = -1 at the left chip's centre,
/// +1 at the right chip's) and its height relative to the chip
/// centres, both at the design size, so the chain holds its
/// shape at any screen width. The four outermost dots on each
/// side continue the measured end slope behind the chips, where
/// the artwork itself hides its own chain ends.
class _BeadChainPainter extends CustomPainter {
  const _BeadChainPainter({required this.color});

  final Color color;

  static const _dots = <(double, double, double)>[
    (-0.934, 6.33, 2.30),
    (-0.840, 1.81, 2.30),
    (-0.747, -1.86, 2.30),
    (-0.653, -4.75, 2.30),
    (-0.563, -6.75, 2.39),
    (-0.466, -8.47, 2.29),
    (-0.376, -11.72, 2.39),
    (-0.286, -15.39, 2.29),
    (-0.192, -17.86, 2.42),
    (-0.098, -19.24, 2.39),
    (-0.001, -19.76, 2.29),
    (0.096, -19.24, 2.42),
    (0.190, -17.82, 2.42),
    (0.283, -15.23, 2.32),
    (0.373, -11.71, 2.32),
    (0.464, -8.49, 2.22),
    (0.560, -6.77, 2.36),
    (0.653, -4.75, 2.30),
    (0.747, -1.86, 2.30),
    (0.840, 1.81, 2.30),
    (0.934, 6.33, 2.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.8);
    final cx = size.width / 2;
    final halfSpan = cx - 49.5;
    if (halfSpan <= 0) return;
    for (final (u, yOff, r) in _dots) {
      canvas.drawCircle(Offset(cx + u * halfSpan, 27.5 + yOff), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeadChainPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Slim lifetime stats row under the guide: games played, games
/// twinned, and the twin rate between them. Hidden until the first
/// game is on the record, so a new player never sees a row of zeroes.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StatsService.instance,
      builder: (context, _) {
        return FutureBuilder<LifetimeStats>(
          future: StatsService.instance.getStats(),
          initialData: StatsService.instance.cached,
          builder: (context, snapshot) {
            final stats = snapshot.data ?? StatsService.instance.cached;
            if (stats == null || stats.totalGamesPlayed == 0) {
              return const SizedBox.shrink();
            }
            final rate = (stats.convergenceRate * 100).round();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 350),
                child: Row(
                  children: [
                    _StatCell(value: '${stats.totalGamesPlayed}', label: 'Games played'),
                    const _StatDivider(),
                    _StatCell(value: '${stats.totalGamesTwinned}', label: 'Twinned'),
                    const _StatDivider(),
                    _StatCell(value: '$rate%', label: 'Twin rate'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: context.watch<AppSession>().palette.border,
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.accent2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent2.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: p.accent2Ink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.45,
                color: p.text.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteList extends StatelessWidget {
  const _InviteList({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GameInvite>>(
      stream: session.backend.watchInvites(),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const <GameInvite>[];
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_rounded,
                  color: session.palette.accentInk,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Waiting for you',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: session.palette.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final invite in invites)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: session.palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: session.palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CharacterAvatar(name: invite.fromName, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${invite.fromName} started a game',
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: session.palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Room ${invite.roomCode}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: session.palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: session.palette.muted,
                      ),
                      onPressed: () =>
                          session.backend.dismissInvite(invite.roomCode),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: session.palette.accent,
                        foregroundColor: session.palette.onAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        session.backend.dismissInvite(invite.roomCode);
                        RoomLauncher.joinAndOpen(
                          context,
                          session,
                          invite.roomCode,
                        );
                      },
                      child: Text(
                        'Play',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    const steps = [
      'You both type a word in private.',
      'Both words are revealed at the same time.',
      'Now aim for a word in between the two. So do they.',
      'Keep going until you both type the same word. Then you have twinned!',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: p.accentInk,
              ),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        color: p.accentInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        height: 1.45,
                        color: p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

