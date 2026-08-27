import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/word_utils.dart';
import '../../game/word_similarity.dart';
import '../app_theme.dart';

/// Word entry for the round.
///
/// Because an out-of-vocabulary word scores zero, the composer checks the
/// bundled table as you type and says so before you commit — the rule stays
/// visible instead of biting you at reveal.
class WordComposer extends StatefulWidget {
  const WordComposer({
    super.key,
    required this.onSubmit,
    required this.similarity,
    required this.enabled,
    required this.isSubmitting,
  });

  final Future<bool> Function(String word) onSubmit;
  final WordSimilarity similarity;
  final bool enabled;
  final bool isSubmitting;

  @override
  State<WordComposer> createState() => _WordComposerState();
}

class _WordComposerState extends State<WordComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  WordVectorLookup? _lookup;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final word = normalizeWord(_controller.text);
    setState(() {
      _lookup = word.length < 2 ? null : widget.similarity.lookup(word);
    });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enabled && !widget.isSubmitting,
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
        _VocabNote(lookup: _lookup),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: widget.enabled && !widget.isSubmitting ? _submit : null,
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
      ],
    );
  }
}

class _VocabNote extends StatelessWidget {
  const _VocabNote({required this.lookup});

  final WordVectorLookup? lookup;

  @override
  Widget build(BuildContext context) {
    final l = lookup;
    if (l == null) return const SizedBox(height: 22);

    final (text, color) = switch (l.kind) {
      LookupKind.exact => ('in the dictionary', AppTheme.converged),
      LookupKind.approximate => (
        'scored as "${l.matchedToken}"',
        AppTheme.seed,
      ),
      LookupKind.outOfVocabulary => (
        'unknown word, scores 0',
        Theme.of(context).colorScheme.error,
      ),
    };

    return SizedBox(
      height: 22,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.4,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

