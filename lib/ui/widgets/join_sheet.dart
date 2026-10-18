import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../../services/room_code.dart';

/// Dedicated Join Room modal sheet:
/// - 5 large letter boxes matching RoomCode.length
/// - Auto-uppercase formatting & auto-submit on 5th valid character
class JoinSheet extends StatefulWidget {
  const JoinSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navy900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const JoinSheet(),
    );
  }

  @override
  State<JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<JoinSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    var cleaned = RoomCode.normalize(val);
    if (cleaned.length > RoomCode.length) {
      cleaned = cleaned.substring(0, RoomCode.length);
    }
    if (cleaned != val) {
      _controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    setState(() {});
    if (RoomCode.isValid(cleaned)) {
      Navigator.of(context).pop(cleaned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final code = _controller.text;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
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
          Text(
            'Join a match',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the ${RoomCode.length}-character code shared by your friend.',
            style: const TextStyle(fontSize: 13.5, color: AppTheme.mist),
          ),
          const SizedBox(height: 26),

          // 5 Big Letter Boxes
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < RoomCode.length; i++) ...[
                  Container(
                    width: 52,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.navy800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: i == code.length
                            ? AppTheme.lime
                            : (i < code.length
                                ? AppTheme.lime.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12)),
                        width: i == code.length ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.lime,
                      ),
                    ),
                  ),
                  if (i < RoomCode.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Hidden Input Field
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: RoomCode.length,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.text,
                onChanged: _onChanged,
              ),
            ),
          ),

        ],
        ),
      ),
    );
  }
}
