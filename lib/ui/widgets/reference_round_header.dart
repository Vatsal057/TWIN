import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import 'character_avatar.dart';

/// Top Player Slots matching reference Screenshot 2:
/// Left: the local player, under their own profile name, with live turn/locked status
/// Right: Partner (e.g. Maya) with avatar and thinking/locked status
class ReferenceRoundHeader extends StatelessWidget {
  const ReferenceRoundHeader({
    super.key,
    required this.localName,
    required this.opponentName,
    required this.localIsPlayerOne,
    required this.round,
    required this.maxRounds,
    this.opponentSubmitted = false,
    this.localSubmitted = false,
    this.localAvatarId,
    this.opponentAvatarId,
  });

  final String localName;
  final String opponentName;
  final bool localIsPlayerOne;
  final int round;
  final int? maxRounds;
  final bool opponentSubmitted;
  final bool localSubmitted;

  /// Illustrated avatar chosen in Settings, shown on the local player.
  final String? localAvatarId;

  /// The avatar the opponent picked on their device, shared via the room.
  /// Null for older rooms, where the face falls back to their name.
  final String? opponentAvatarId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Local player, shown under their own name
          Column(
            children: [
              CharacterAvatar(
                name: localName,
                size: 72,
                status: localSubmitted ? 'locked' : 'turn',
                avatarId: localAvatarId,
              ),
              const SizedBox(height: 10),
              Text(
                localName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              if (localSubmitted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 12, color: AppTheme.mist),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mist,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Your turn',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.lime,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Opponent Player (e.g. Maya)
          Column(
            children: [
              CharacterAvatar(
                name: opponentName,
                size: 72,
                status: opponentSubmitted ? 'locked' : null,
                avatarId: opponentAvatarId,
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                  children: [
                    TextSpan(
                      text: opponentName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (opponentSubmitted)
                      const TextSpan(
                        text: ' · locked in',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mist,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (opponentSubmitted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 12, color: AppTheme.mist),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mist,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThreeWaitingDots(),
                    const SizedBox(width: 5),
                    Text(
                      'thinking',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mist,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThreeWaitingDots extends StatefulWidget {
  @override
  State<_ThreeWaitingDots> createState() => _ThreeWaitingDotsState();
}

class _ThreeWaitingDotsState extends State<_ThreeWaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - (i * 0.2)) % 1.0;
            final alpha = 0.25 + (0.75 * (1.0 - (t - 0.5).abs() * 2).clamp(0.0, 1.0));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mist.withValues(alpha: alpha),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
