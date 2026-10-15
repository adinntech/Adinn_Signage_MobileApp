import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Four large MPIN boxes driven by one invisible numeric text field, so the
/// system keyboard, paste and backspace all behave natively.
class MpinField extends StatefulWidget {
  const MpinField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onCompleted;

  @override
  State<MpinField> createState() => _MpinFieldState();
}

class _MpinFieldState extends State<MpinField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final hasError = widget.errorText != null;
    return Semantics(
      label: '${widget.label}, ${value.length} of 4 digits entered',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.navy)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.enabled ? _focus.requestFocus : null,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (i) {
                    final filled = i < value.length;
                    final active = _focus.hasFocus && i == value.length.clamp(0, 3);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: filled ? AppColors.royal.withValues(alpha: 0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasError
                              ? AppColors.error
                              : active
                                  ? AppColors.royal
                                  : filled
                                      ? AppColors.royal.withValues(alpha: 0.5)
                                      : const Color(0xFFD5DBE8),
                          width: active || hasError ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        scale: filled ? 1 : 0,
                        child: const Icon(Icons.circle, size: 16, color: AppColors.navy),
                      ),
                    );
                  }),
                ),
                // Invisible field on top captures the keyboard input.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      showCursor: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (v) {
                        if (v.length == 4) widget.onCompleted?.call();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(widget.errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
