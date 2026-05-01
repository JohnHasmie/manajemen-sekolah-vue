// Brand-aligned language picker bottom sheet.
//
// Replaces the legacy `AlertDialog` shown when the user taps the
// globe icon in the dashboard header. Per the Phase-5 mockup it's
// a rounded-top bottom sheet with two big tappable tiles
// (Bahasa Indonesia / English), each carrying a flag, native +
// international name, and a status line.
//
// State plumbing
// --------------
// Reads `languageRiverpod`'s `currentLanguage` to determine which
// tile is active. Writing goes through `LanguageProvider.setLanguage`
// which also persists to SharedPreferences and broadcasts via
// `notifyListeners()` — so all consumers re-render automatically.
//
// The amber info card sets correct user expectations: switching the
// language refreshes the rebuilt subtree but keeps login + active
// tab intact (no signout, no navigation reset).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Show the language picker as a brand bottom sheet. Pops itself
/// after a successful switch — caller doesn't need to handle the
/// return value.
Future<void> showLanguagePickerSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _LanguagePickerSheet(ref: ref),
  );
}

class _LanguagePickerSheet extends StatelessWidget {
  final WidgetRef ref;

  const _LanguagePickerSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final current = lang.currentLanguage;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title block
          Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'Pilih Bahasa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berlaku di seluruh aplikasi',
                    style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: AppSpacing.md),

          _LanguageTile(
            flag: const _IndonesianFlag(),
            nativeName: 'Bahasa Indonesia',
            internationalName: 'Indonesian · Resmi',
            active: current == LanguageProvider.indonesian,
            onTap: () => _onPick(context, LanguageProvider.indonesian),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LanguageTile(
            flag: const _UkFlag(),
            nativeName: 'English',
            internationalName: 'Inggris · International',
            active: current == LanguageProvider.english,
            onTap: () => _onPick(context, LanguageProvider.english),
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: AppSpacing.md),

          // Amber info card — sets expectation that switching
          // refreshes the visible subtree but keeps login + tab
          // state intact.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'i',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Aplikasi akan refresh setelah ganti bahasa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Data login + tab aktif tetap dipertahankan',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Tutup
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Tutup',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPick(BuildContext context, String code) {
    final current = ref.read(languageRiverpod).currentLanguage;
    if (current == code) {
      Navigator.of(context).pop();
      return;
    }
    ref.read(languageRiverpod).setLanguage(code);
    Navigator.of(context).pop();
  }
}

class _LanguageTile extends StatelessWidget {
  final Widget flag;
  final String nativeName;
  final String internationalName;
  final bool active;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.flag,
    required this.nativeName,
    required this.internationalName,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBlue = ColorUtils.brandAzureDeep;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF0F9FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? activeBlue : const Color(0xFFE2E8F0),
              width: active ? 1.5 : 0.75,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 48, height: 48, child: flag),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nativeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      internationalName,
                      style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'Aktif sekarang'
                          : 'Tap untuk mengaktifkan',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? activeBlue : ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: activeBlue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painted Indonesian flag (red over white) inside a 48x48 rounded
/// square. Painted rather than asset-loaded so the widget stays
/// dependency-free and crisp at any density.
class _IndonesianFlag extends StatelessWidget {
  const _IndonesianFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(color: const Color(0xFFFF0000)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painted Union Jack inside a 48x48 rounded square.
class _UkFlag extends StatelessWidget {
  const _UkFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(painter: _UnionJackPainter()),
    );
  }
}

class _UnionJackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = const Color(0xFF012169);
    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final whiteFill = Paint()..color = Colors.white;
    final redFill = Paint()..color = const Color(0xFFC8102E);

    final w = size.width;
    final h = size.height;

    // Background blue
    canvas.drawRect(Offset.zero & size, blue);

    // Diagonals (white wide then red thin)
    canvas.drawLine(Offset.zero, Offset(w, h), white);
    canvas.drawLine(Offset(w, 0), Offset(0, h), white);
    canvas.drawLine(Offset.zero, Offset(w, h), red);
    canvas.drawLine(Offset(w, 0), Offset(0, h), red);

    // Cross (white wide then red thin)
    canvas.drawRect(
      Rect.fromLTWH((w - 8) / 2, 0, 8, h),
      whiteFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, (h - 8) / 2, w, 8),
      whiteFill,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - 4) / 2, 0, 4, h),
      redFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, (h - 4) / 2, w, 4),
      redFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
