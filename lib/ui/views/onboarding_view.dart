import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_avatars.dart';
import '../../services/sound_service.dart';
import '../../state/app_session.dart';
import '../app_theme.dart';
import '../widgets/character_avatar.dart';
import '../widgets/reference_word_sticker.dart';

/// First-run onboarding, shown once before the tabs: three scenes that
/// teach the game with its own stickers, then one short step for a
/// name and a face. The name becomes the player's username on the
/// spot (@vatsal, or @vatsal.42 when that is taken), shown live as
/// they type, and that exact username is the one claimed. Brand stage: navy in every theme, like the boot
/// screen and the result screen.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  String _avatarId = AppAvatars.fallback;
  bool _saving = false;

  /// The username the final step is showing right now, without the
  /// @. Suggested from the name as it is typed and checked against
  /// the registry, swappable via the refresh button, and claimed
  /// exactly as shown when the player continues.
  String _username = '';
  bool _checkingId = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {});
    _debounce?.cancel();
    if (_name.text.trim().isEmpty) {
      setState(() => _username = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _suggest);
  }

  Future<void> _suggest({bool refresh = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _checkingId = true);
    final found = await context.read<AppSession>().suggestUsername(
      name,
      avoid: refresh && _username.isNotEmpty ? _username : null,
    );
    if (!mounted) return;
    setState(() {
      _username = found;
      _checkingId = false;
    });
  }

  void _goTo(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(AppSession session) async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your name first. Your ID is made from it.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    SoundService.instance.twin();
    var username = _username;
    if (username.isEmpty) {
      username = await session.suggestUsername(_name.text.trim());
    }
    await session.completeOnboarding(
      name: _name.text,
      avatarId: _avatarId,
      username: username,
    );
    // The session gate swaps this screen for the tabs on its own.
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final onProfileStep = _page == 3;
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 4),
              child: Row(
                children: [
                  Text(
                    'TWIN',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (!onProfileStep)
                    TextButton(
                      onPressed: () => _goTo(3),
                      child: Text(
                        'Skip intro',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.mist,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  SoundService.instance.tick();
                },
                children: [
                  _IntroPage(
                    headline: 'Two minds.\nOne word.',
                    sub: 'You and a friend each pick a word. '
                        'Any word at all.',
                    scene: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        WordSticker(
                          word: 'OCEAN',
                          tone: WordTone.lime,
                          rotate: -10,
                        ),
                        DottedChainBridge(),
                        WordSticker(
                          word: 'DESERT',
                          tone: WordTone.coral,
                          rotate: 10,
                        ),
                      ],
                    ),
                  ),
                  _IntroPage(
                    headline: 'Meet in\nthe middle.',
                    sub: 'Round by round, both of you name the word '
                        'between your two words. You get closer '
                        'every time.',
                    scene: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            WordSticker(
                              word: 'SAND',
                              tone: WordTone.lime,
                              rotate: -8,
                              isLarge: false,
                            ),
                            SizedBox(width: 14),
                            WordSticker(
                              word: 'WATER',
                              tone: WordTone.coral,
                              rotate: 8,
                              isLarge: false,
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 20,
                            color: AppTheme.mist,
                          ),
                        ),
                        const WordSticker(
                          word: 'BEACH',
                          tone: WordTone.lime,
                          rotate: -4,
                        ),
                      ],
                    ),
                  ),
                  _IntroPage(
                    headline: 'Say it together.\nTwin.',
                    sub: 'When you both land on the same word, '
                        'you twin. That is the whole game.',
                    scene: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ConfettiDots(),
                        const SizedBox(height: 18),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(16, 10),
                              child: const WordSticker(
                                word: 'BEACH',
                                tone: WordTone.coral,
                                rotate: 8,
                              ),
                            ),
                            const WordSticker(
                              word: 'BEACH',
                              tone: WordTone.lime,
                              rotate: -6,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _ConfettiDots(flip: true),
                      ],
                    ),
                  ),
                  _profileStep(session),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppTheme.lime
                                : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (!onProfileStep)
                    FilledButton(
                      onPressed: () => _goTo(_page + 1),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.lime,
                        foregroundColor: AppTheme.navy950,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _page == 2 ? 'Make my profile' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStep(AppSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Make it yours',
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your name and face are all a friend needs to spot you. '
            'No email, no password.',
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              color: AppTheme.mist,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: CharacterAvatar(
              name: _name.text.trim(),
              size: 84,
              avatarId: _avatarId,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            onChanged: (_) => _onNameChanged(),
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: GoogleFonts.outfit(color: AppTheme.mist),
              counterText: '',
              filled: true,
              fillColor: AppTheme.navy800,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.navy900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Text(
                  'YOUR ID',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppTheme.mist,
                  ),
                ),
                const Spacer(),
                Text(
                  _username.isEmpty ? '…' : '@$_username',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.lime,
                  ),
                ),
                const SizedBox(width: 6),
                if (_checkingId)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.mist,
                    ),
                  )
                else
                  IconButton(
                    onPressed:
                        _username.isEmpty ? null : () => _suggest(refresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    color: AppTheme.mist,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Made from your name, and only yours: it is checked '
            'against every player. Not feeling it? Tap refresh for '
            'another. You can edit it later in Settings.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mist),
          ),
          const SizedBox(height: 20),
          Text(
            'PICK YOUR FACE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppTheme.mist,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final id in AppAvatars.ids)
                GestureDetector(
                  onTap: () {
                    setState(() => _avatarId = id);
                    SoundService.instance.tick();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: id == _avatarId
                            ? AppTheme.lime
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: CharacterAvatar(
                      name: '',
                      size: 46,
                      avatarId: id,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _saving ? null : () => _finish(session),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.lime,
              foregroundColor: AppTheme.navy950,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start playing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.headline,
    required this.sub,
    required this.scene,
  });

  final String headline;
  final String sub;
  final Widget scene;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 190, child: Center(child: scene)),
          const SizedBox(height: 34),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: AppTheme.mist,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small scatter of brand-coloured dots, the confetti shorthand
/// the result screen uses, kept still here.
class _ConfettiDots extends StatelessWidget {
  const _ConfettiDots({this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final dots = <({double size, Color color, double gap})>[
      (size: 7, color: AppTheme.lime, gap: 0),
      (size: 5, color: AppTheme.coral, gap: 26),
      (size: 8, color: const Color(0xFFFFD166), gap: 18),
      (size: 5, color: Colors.white, gap: 30),
      (size: 6, color: AppTheme.coral, gap: 20),
      (size: 7, color: AppTheme.lime, gap: 24),
    ];
    final ordered = flip ? dots.reversed.toList() : dots;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in ordered) ...[
          if (d.gap > 0) SizedBox(width: d.gap),
          Container(
            width: d.size,
            height: d.size,
            decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}
