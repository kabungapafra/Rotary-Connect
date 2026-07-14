import 'package:flutter/material.dart';

/// Owns a [TextEditingController] kept in sync with an externally-stored
/// [value], for text fields whose source of truth lives in AppState.
///
/// Creating a new controller inside `build` (the pattern this replaces)
/// resets the selection and IME composing region on every rebuild — every
/// keystroke, since each one notifies AppState — which drops fast keystrokes,
/// pins the cursor to the end so mid-text edits are impossible, and leaks
/// the discarded controllers.
class SyncedTextField extends StatefulWidget {
  final String value;
  final Widget Function(BuildContext context, TextEditingController controller)
      builder;
  const SyncedTextField(
      {super.key, required this.value, required this.builder});

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only push external/programmatic changes (clearing a form, opening an
    // editor on a different record) into the controller. When the change
    // came from the user typing, text already matches — leaving the
    // controller alone preserves cursor position and IME composition.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
