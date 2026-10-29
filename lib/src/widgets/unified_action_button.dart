import 'package:flutter/material.dart';

/// Consistent action button used across order screens.
///
/// Filled variant renders a solid [color] background with white content;
/// outlined variant renders a transparent background with a tinted border.
class UnifiedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool outlined;
  final bool fullWidth;
  final bool loading;

  const UnifiedActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.icon,
    this.outlined = false,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 48,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : color,
          foregroundColor: outlined ? color : Colors.white,
          disabledBackgroundColor: outlined ? Colors.transparent : color.withValues(alpha: 0.4),
          disabledForegroundColor: outlined ? color.withValues(alpha: 0.6) : Colors.white,
          side: outlined ? BorderSide(color: color.withValues(alpha: 0.3), width: 2) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: outlined ? color : Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: outlined ? color : Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
    if (fullWidth) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}
