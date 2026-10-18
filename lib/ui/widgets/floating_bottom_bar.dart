import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/sound_service.dart';
import '../twin_palette.dart';
import 'bouncy_tap.dart';
import 'character_avatar.dart';

enum MainTab { play, chat, history, profile }

/// Liquid glass floating capsule navigation bar matching the reference screenshot:
/// - Real backdrop blur with ImageFilter.blur
/// - Translucent liquid glass gradient and subtle specular outline
/// - Active tab indicator with soft pill glow and lime accent
/// - Unread message counter badge on Chat
class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.palette,
    this.unreadCount = 0,
    this.profileAvatarId,
    this.profileName,
  });

  final MainTab currentTab;
  final ValueChanged<MainTab> onTabSelected;
  final TwinPalette palette;
  final int unreadCount;

  /// The Profile tab wears the player's own face instead of an icon.
  final String? profileAvatarId;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.barA, palette.barB],
            ),
            border: Border.all(
              color: palette.text.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0x2213162D),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabItem(
                palette: palette,
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                isSelected: currentTab == MainTab.play,
                onTap: () {
                  HapticFeedback.selectionClick();
                  SoundService.instance.tick();
                  onTabSelected(MainTab.play);
                },
              ),
              const SizedBox(width: 4),
              _TabItem(
                palette: palette,
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                isSelected: currentTab == MainTab.chat,
                badgeCount: unreadCount,
                onTap: () {
                  HapticFeedback.selectionClick();
                  SoundService.instance.tick();
                  onTabSelected(MainTab.chat);
                },
              ),
              const SizedBox(width: 4),
              _TabItem(
                palette: palette,
                icon: Icons.access_time_rounded,
                label: 'History',
                isSelected: currentTab == MainTab.history,
                onTap: () {
                  HapticFeedback.selectionClick();
                  SoundService.instance.tick();
                  onTabSelected(MainTab.history);
                },
              ),
              const SizedBox(width: 4),
              _TabItem(
                palette: palette,
                label: 'Profile',
                isSelected: currentTab == MainTab.profile,
                avatarId: profileAvatarId,
                avatarName: profileName,
                onTap: () {
                  HapticFeedback.selectionClick();
                  SoundService.instance.tick();
                  onTabSelected(MainTab.profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.palette,
    this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
    this.avatarId,
    this.avatarName,
  });

  final TwinPalette palette;
  final IconData? icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  /// When set, the tab shows this face instead of an [icon].
  final String? avatarId;
  final String? avatarName;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scaleDown: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.text.withValues(alpha: 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: isSelected
              ? Border.all(
                  color: palette.text.withValues(alpha: 0.12),
                  width: 1,
                )
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (avatarId != null)
                  CharacterAvatar(
                    name: avatarName ?? '',
                    size: 22,
                    avatarId: avatarId,
                  )
                else
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? palette.accentInk : palette.muted.withValues(alpha: 0.8),
                  ),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: palette.accent2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? palette.accentInk : palette.muted.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

