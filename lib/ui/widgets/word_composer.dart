import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

/// Word entry for the round.
///
/// Any word is allowed. There is no dictionary and no scoring, so nothing to
/// warn about — whatever the two of you agree on is what counts.
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
    final ok = await widget.onSubmit(_controller.text);
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
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: active,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.send,
          maxLength: 40,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9'\- ]")),
          ],
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'your word',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: active ? _submit : null,
          child: widget.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.ink,
                  ),
                )
              : const Text('Lock it in'),
        ),
        const SizedBox(height: 10),
        Text(
          'Hidden until you have both committed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.3,
            color: AppTheme.parchment.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
