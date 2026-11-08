import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/rtl_detection_service.dart';
import '../services/sentence_case_service.dart';

/// A TextField that dynamically switches textDirection and textAlign based on
/// whether the first typed non-whitespace character is Persian/Arabic or Latin,
/// and applies SentenceCase formatting by default.
class RtlAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const RtlAwareTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.style,
    this.maxLines = 1,
    this.autofocus = false,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
  });

  @override
  State<RtlAwareTextField> createState() => _RtlAwareTextFieldState();
}

class _RtlAwareTextFieldState extends State<RtlAwareTextField> {
  late TextDirection _dir;

  @override
  void initState() {
    super.initState();
    _dir = RtlDetectionService.resolveDirection(widget.controller.text);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newDir = RtlDetectionService.resolveDirection(widget.controller.text);
    if (newDir != _dir && mounted) {
      setState(() {
        _dir = newDir;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textDirection: _dir,
      textAlign: _dir == TextDirection.rtl ? TextAlign.right : TextAlign.left,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: widget.inputFormatters ?? [SentenceCaseTextInputFormatter()],
      style: widget.style,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      decoration: widget.decoration,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
    );
  }
}
