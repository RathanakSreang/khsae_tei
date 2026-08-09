import 'package:flutter/material.dart';

import 'theme.dart';

/// Dark card container matching Home's status/stats cards, reused across
/// Settings so both tabs read as one consistent app.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material, not a plain Container: ListTile/SwitchListTile and other
    // interactive children paint their background and ink splashes on the
    // nearest Material ancestor - an opaque DecoratedBox in between (like a
    // plain Container's decoration) would silently hide those effects.
    return Material(
      color: kCardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: kCardBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

/// Primary-action pill button (gradient teal fill) - same visual language
/// as Home's Start/Stop button, for Settings' Connect/Test Whip actions.
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({required this.onPressed, required this.label, this.icon, this.height = 54, super.key});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(height / 2),
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled ? null : const LinearGradient(colors: [kAccent, Color(0xFF29C7B5)]),
            color: disabled ? Colors.white.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(height / 2),
            border: disabled ? Border.all(color: kCardBorder) : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: disabled ? Colors.white38 : Colors.black87, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: disabled ? Colors.white38 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary-action pill button (outlined) for less prominent actions
/// alongside a [GradientPillButton].
class OutlinedPillButton extends StatelessWidget {
  const OutlinedPillButton({required this.onPressed, required this.label, this.height = 48, super.key});

  final VoidCallback? onPressed;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: kAccent,
          disabledForegroundColor: Colors.white38,
          side: const BorderSide(color: kCardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
