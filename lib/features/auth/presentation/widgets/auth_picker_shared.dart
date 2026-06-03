// Shared chrome for the login-screen picker steps (school / role).
// Both the school picker (Frame D) and the role picker (Frame E) from
// `_design/auth_login_school_role_redesign.html` reuse the same header,
// step-dot indicator, section label, search bar, and sticky footer CTA.
//
// These widgets were extracted verbatim from
// `auth_form_builder_mixin.dart` as part of a structural readability
// split — behavior is unchanged.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class PickerHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String subtitle;
  final Widget? stepDots;

  const PickerHeader({
    super.key,
    required this.kicker,
    required this.title,
    required this.subtitle,
    this.stepDots,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            kicker,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ColorUtils.slate900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate500,
              height: 1.45,
            ),
          ),
        ),
        if (stepDots != null) ...[const SizedBox(height: 10), stepDots!],
      ],
    );
  }
}

class StepDots extends StatelessWidget {
  final int active; // 0-based or 1-based — we treat as 1-based.
  final int total;

  const StepDots({super.key, required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? ColorUtils.brandCobalt : ColorUtils.slate200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate500,
        letterSpacing: 1,
      ),
    );
  }
}

class PickerSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const PickerSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(fontSize: 12.5, color: ColorUtils.slate900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: ColorUtils.slate400,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 16,
          color: ColorUtils.slate400,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.brandCobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

/// Sticky-style footer rendered inline below the picker list. The
/// outer form-card already gives us a bottom-of-screen feel since the
/// brand band sits above and the page background sits below, so we
/// don't need to use `Scaffold.bottomNavigationBar` here.
class PickerFooterCta extends StatelessWidget {
  final String primaryLabel;
  final bool primaryEnabled;
  final bool isLoading;
  final Color? primaryColor;
  final Future<void> Function() onPrimary;
  final VoidCallback onSecondary;

  const PickerFooterCta({
    super.key,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.isLoading,
    required this.onPrimary,
    required this.onSecondary,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = primaryColor ?? ColorUtils.brandCobalt;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: primaryEnabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [base, _lighten(base)],
                    )
                  : LinearGradient(
                      colors: [ColorUtils.slate300, ColorUtils.slate300],
                    ),
              boxShadow: primaryEnabled
                  ? [
                      BoxShadow(
                        color: base.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: primaryEnabled ? onPrimary : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Memproses…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onSecondary,
          child: Text(
            AppLocalizations.backToLogin.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandCobalt,
            ),
          ),
        ),
      ],
    );
  }

  Color _lighten(Color c) {
    // A consistent 18% lightness bump so the gradient still reads as
    // "depth" without going past the brand swatch on either end.
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
  }
}
