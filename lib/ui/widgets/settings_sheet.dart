import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../../core/app_avatars.dart';
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
      backgroundColor: AppTheme.navy900,
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
  late String _selectedAvatarId = widget.session.profileAvatarId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.session.setDisplayName(name);
    }
    widget.session.setProfileAvatarId(_selectedAvatarId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white.withValues(alpha: 0.2),
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
                    icon: const Icon(Icons.close_rounded, color: AppTheme.mist),
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
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: TextField(
                  controller: _nameController,
                  maxLength: 18,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'You',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.mist.withValues(alpha: 0.6)),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Your avatar
              Text(
                'Your avatar',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mist,
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
                            color: _selectedAvatarId == id ? AppTheme.lime : Colors.transparent,
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
              const SizedBox(height: 32),

              // Save button
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: const Color(0xFF151434),
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
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.coral),
                  label: const Text('Reset demo data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.coral,
                    minimumSize: const Size.fromHeight(54),
                    side: BorderSide(color: AppTheme.coral.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Offline mode: your profile, games and chats live locally in memory. Reset brings back the sample games.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.mist,
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
