import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../state/app_session.dart';
import '../twin_palette.dart';
import '../widgets/character_avatar.dart';
import '../widgets/settings_sheet.dart';

/// The Profile tab: the player's own face and name, the profile
/// editor, and how this device is signed in. TWIN has no passwords:
/// online play runs on an automatic guest account, so the account
/// section says exactly that, plus the player id this device's
/// games are recorded against.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final p = session.palette;
    final online = session.isNetworked;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: CharacterAvatar(
                  name: session.displayName,
                  size: 96,
                  avatarId: session.profileAvatarId,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                session.displayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: p.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                online ? 'Signed in as guest' : 'Offline practice',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => SettingsSheet.show(context, session),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(
                  'Edit profile',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'THEME',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: p.muted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final tp in TwinPalette.all) ...[
                    Expanded(
                      child: _ThemeOption(
                        palette: tp,
                        selected: session.themeId == tp.id,
                        onTap: () => session.setThemeId(tp.id),
                      ),
                    ),
                    if (tp.id != TwinPalette.all.last.id)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.border),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    _AccountRow(
                      palette: p,
                      label: 'Status',
                      value: online ? 'Online' : 'Offline practice',
                    ),
                    Divider(height: 1, color: p.border),
                    _AccountRow(
                      palette: p,
                      label: 'Account',
                      value: online
                          ? 'Guest, signed in automatically'
                          : 'On this device only',
                    ),
                    Divider(height: 1, color: p.border),
                    _AccountRow(
                      palette: p,
                      label: 'Username',
                      value: '@${session.username}',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: '@${session.username}'),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Username copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (session.backendFallbackReason case final reason?) ...[
                const SizedBox(height: 14),
                Text(
                  reason,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: p.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

/// One theme choice in the picker. The card is drawn in the
/// theme's own colours, so it previews honestly whichever theme
/// is currently active.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final TwinPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tp.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? tp.accent : tp.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _dot(tp.accent),
                const SizedBox(width: 5),
                _dot(tp.accent2),
                const SizedBox(width: 5),
                _dot(tp.raised),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: tp.accentInk,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tp.name,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: tp.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: palette.border),
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.palette,
    required this.label,
    required this.value,
    this.onTap,
  });

  final TwinPalette palette;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 15, color: palette.muted),
            ],
          ],
        ),
      ),
    );
  }
}
