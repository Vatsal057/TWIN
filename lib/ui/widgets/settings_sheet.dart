import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_avatars.dart';
import '../../services/sound_service.dart';
import '../../state/app_session.dart';

/// Settings & Avatar Customizer Sheet matching React SettingsSheet:
/// - Display Name text editor
/// - Memoji-style illustrated avatar picker
/// - How to play visual rules guide
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.session});

  final AppSession session;

  static Future<void> show(BuildContext context, AppSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: session.palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SettingsSheet(session: session),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.session.displayName);
  late final TextEditingController _usernameController =
      TextEditingController(text: widget.session.username);
  late String _selectedAvatarId = widget.session.profileAvatarId;
  bool _soundOn = SoundService.instance.enabled;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = widget.session;
    // The username is claimed before anything else saves: if it is
    // malformed or taken, the sheet stays open with the reason shown
    // and nothing else changes underneath the player.
    final wanted = _usernameController.text
        .trim()
        .toLowerCase()
        .replaceAll('@', '');
    if (wanted != session.username) {
      if (!AppSession.isValidUsername(wanted)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usernames are 3-20 characters: letters, numbers, dots or underscores.',
            ),
          ),
        );
        return;
      }
      if (!await session.backend.isUsernameAvailable(wanted)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That username is taken.')),
        );
        return;
      }
      await session.claimUsername(
        wanted,
        nameForFallback: session.displayName,
      );
    }
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      session.setDisplayName(name);
    }
    session.setProfileAvatarId(_selectedAvatarId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.text.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: p.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Your name
              Text(
                'Your name',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: p.text.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: TextField(
                  controller: _nameController,
                  maxLength: 18,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
                  decoration: InputDecoration(
                    hintText: 'You',
                    hintStyle: GoogleFonts.outfit(color: p.muted.withValues(alpha: 0.6)),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Your username
              Text(
                'Your username',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: p.text.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
                  decoration: InputDecoration(
                    prefixText: '@ ',
                    prefixStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: p.muted),
                    hintText: 'username',
                    hintStyle: GoogleFonts.outfit(color: p.muted.withValues(alpha: 0.6)),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your unique ID. Friends can find you by it.',
                style: GoogleFonts.outfit(fontSize: 12, color: p.muted),
              ),
              const SizedBox(height: 24),

              // Your avatar
              Text(
                'Your avatar',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final id in AppAvatars.ids)
                    InkWell(
                      onTap: () {
                        setState(() => _selectedAvatarId = id);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedAvatarId == id ? p.accent : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            AppAvatars.assetFor(id),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // Sounds
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sounds',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Soft clicks and chimes for locks, reveals and chats.',
                          style: GoogleFonts.outfit(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _soundOn,
                    onChanged: (value) {
                      setState(() => _soundOn = value);
                      SoundService.instance.setEnabled(value);
                    },
                    activeTrackColor: p.accent,
                    activeThumbColor: p.onAccent,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save button
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (!widget.session.isNetworked) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    widget.session.backend.initialize();
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.refresh_rounded, size: 16, color: p.accent2Ink),
                  label: const Text('Reset demo data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accent2Ink,
                    minimumSize: const Size.fromHeight(54),
                    side: BorderSide(color: p.accent2.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Offline mode: your profile, games and chats live locally in memory. Reset brings back the sample games.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
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
