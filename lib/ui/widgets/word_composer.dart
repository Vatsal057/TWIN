import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Word input and "Lock it in" button matching reference Screenshot 2:
/// - Rounded capsule input ("Type your word") with frosted background and subtle border
/// - High-contrast neon lime "Lock it in" capsule CTA button
class WordComposer extends StatefulWidget {
  const WordComposer({
    super.key,
    required this.onSubmit,
    required this.enabled,
    required this.isSubmitting,
  });

  final Future<bool> Function(String word) onSubmit;
  final bool enabled;
  final bool isSubmitting;

  @override
  State<WordComposer> createState() => _WordComposerState();
}

class _WordComposerState extends State<WordComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.enabled || widget.isSubmitting) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    final ok = await widget.onSubmit(text);
    if (ok && mounted) {
      _controller.clear();
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rounded Input Capsule: "Type your word"
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: active,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.send,
            maxLength: 32,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9'\- ]")),
            ],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Type your word',
              // The global theme fills every input with navy800; this field
              // sits inside its own capsule, so the fill must stay off or it
              // paints a square-cornered rectangle inside the pill.
              filled: false,
              hintStyle: GoogleFonts.outfit(
                color: AppTheme.mist.withValues(alpha: 0.75),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // High-contrast Lime "Lock it in" Button matching Screenshot 2
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: active ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lime,
              disabledBackgroundColor: AppTheme.lime.withValues(alpha: 0.45),
              foregroundColor: AppTheme.navy950,
              disabledForegroundColor: AppTheme.navy950.withValues(alpha: 0.5),
              elevation: 4,
              shadowColor: AppTheme.lime.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: widget.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppTheme.navy950,
                    ),
                  )
                : Text(
                    'Lock it in',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy950,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
