import 'package:flutter/material.dart';

/// A compact action button with filled/outline states — horizontal layout.
class ScheduleCardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isFilled;
  final Color primary;
  final VoidCallback onPressed;

  const ScheduleCardActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isFilled,
    required this.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return _buildFilledButton();
    }
    return _buildOutlineButton();
  }

  Widget _buildFilledButton() {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          elevation: 0,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildOutlineButton() {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.35), width: 1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: _buildContent(isOutline: true),
      ),
    );
  }

  Widget _buildContent({bool isOutline = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOutline ? primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
