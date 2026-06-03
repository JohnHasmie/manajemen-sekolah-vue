import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A custom alert dialog for high-stakes academic year transitions.
///
/// Surfaces clear warning indicators and a bulleted list of side effects
/// (archiving previous year, locking grades, shifting filters) before the user
/// commits to changing the active year.
class TahunAjaranActivateDialog extends StatelessWidget {
  final String targetYear;
  final String? currentActiveYear;

  const TahunAjaranActivateDialog({
    super.key,
    required this.targetYear,
    this.currentActiveYear,
  });

  @override
  Widget build(BuildContext context) {
    final warningColor = Colors.amber.shade800;

    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with warning gradient
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [warningColor, Colors.orange.shade700],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aktifkan Tahun Ajaran $targetYear?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentActiveYear != null) ...[
                  Text(
                    'Tahun ajaran $currentActiveYear akan otomatis '
                    'diarsipkan dan tidak bisa diubah lagi.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Konsekuensi mengaktifkan tahun ajaran baru:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Bullet points
                _buildConsequenceRow(
                  'Semua perubahan data (nilai, kehadiran, RPP) di tahun '
                  'ajaran saat ini akan dikunci (read-only).',
                ),
                const SizedBox(height: 10),
                _buildConsequenceRow(
                  'Siswa, guru, dan kelas akan disesuaikan dengan lingkup '
                  'tahun ajaran baru.',
                ),
                const SizedBox(height: 10),
                _buildConsequenceRow(
                  'Notifikasi penyesuaian tahun ajaran akan dikirimkan ke '
                  'guru dan wali murid.',
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: warningColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Ya, Aktifkan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequenceRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: ColorUtils.slate600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
