import 'package:flutter/material.dart';
import '../../core/app_avatars.dart';
import '../app_theme.dart';

/// A player's avatar: one of the illustrated Memoji-style characters
/// (see [AppAvatars]), clipped into a circle, with optional status badges.
///
/// Pass [avatarId] for the local player's chosen character. Without one,
/// the character is derived from [name], so a friend always shows the
/// same face. [customEmoji] is the legacy path from before the
/// illustrated set existed and is only kept so older call sites still
/// render something sensible.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.name,
    this.size = 50,
    this.status,
    this.avatarId,
    this.customEmoji,
    this.customColor,
  });

  final String name;
  final double size;
  final String? status; // 'turn', 'locked', 'online'
  final String? avatarId;
  final String? customEmoji;
  final Color? customColor;

  /// Legacy emoji/colour pairing from the emoji era. Kept for the
  /// fallback path below; new code should use [AppAvatars.forName].
  static ({String emoji, Color color}) infoFor(String name) {
    final lower = name.toLowerCase().trim();
    if (lower == 'you') {
      return (emoji: '🙂', color: AppTheme.lime);
    } else if (lower.contains('ivy')) {
      return (emoji: '👧', color: const Color(0xFFFBE49D));
    } else if (lower.contains('leo')) {
      return (emoji: '👦', color: const Color(0xFFC4DBF6));
    } else if (lower.contains('zoe')) {
      return (emoji: '👱‍♀️', color: const Color(0xFFAECBF7));
    } else if (lower.contains('maya')) {
      return (emoji: '👩‍🦰', color: const Color(0xFFF6C9A8));
    } else if (lower.contains('sam')) {
      return (emoji: '🧒', color: const Color(0xFFB7E4A8));
    }
    return (emoji: '🙂', color: const Color(0xFFAECBF7));
  }

  @override
  Widget build(BuildContext context) {
    final resolvedId = AppAvatars.isValid(avatarId)
        ? avatarId!
        : (customEmoji == null ? AppAvatars.forName(name) : null);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (resolvedId != null)
            ClipOval(
              child: Image.asset(
                AppAvatars.assetFor(resolvedId),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: infoFor(name).color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    infoFor(name).emoji,
                    style: TextStyle(fontSize: size * 0.52, height: 1.1),
                  ),
                ),
              ),
            )
          else
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: customColor ?? infoFor(name).color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                customEmoji ?? infoFor(name).emoji,
                style: TextStyle(
                  fontSize: size * 0.52,
                  height: 1.1,
                ),
              ),
            ),
          if (status == 'turn' || status == 'online')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size > 50 ? 14 : 11,
                height: size > 50 ? 14 : 11,
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.navy950, width: 2),
                ),
              ),
            ),
          if (status == 'locked')
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size > 50 ? 18 : 15,
                height: size > 50 ? 18 : 15,
                decoration: BoxDecoration(
                  color: AppTheme.navy800,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.navy950, width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    size: size > 50 ? 10 : 8,
                    color: AppTheme.mist,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
