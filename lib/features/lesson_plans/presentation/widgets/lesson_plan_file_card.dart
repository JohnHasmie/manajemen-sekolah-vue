// RPP file attachment card. Extracted from lesson_plan_detail_screen.dart.
// Displays a tappable card showing a file icon, name, and a download/open button.
// Like a `<FileCard>` Vue component — shows loading state, fires a callback on tap.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tappable card showing a file attachment for an RPP, with download affordance.
///
/// Constructor params:
/// - [filePath]      — the URL/path of the attached file (used to derive name + extension)
/// - [isDownloading] — when true, shows a spinner instead of the download button
/// - [primaryColor]  — brand colour for the download icon and shadow tint
/// - [onTap]         — callback fired when the user taps (should trigger download + open)
class LessonPlanFileCard extends StatelessWidget {
  final String filePath;
  final bool isDownloading;
  final Color primaryColor;
  final VoidCallback onTap;

  const LessonPlanFileCard({
    super.key,
    required this.filePath,
    required this.isDownloading,
    required this.primaryColor,
    required this.onTap,
  });

  String get _fileName => Uri.parse(filePath).pathSegments.last;

  String get _ext {
    final dotIndex = _fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return _fileName.substring(dotIndex).toLowerCase();
  }

  IconData get _fileIcon {
    switch (_ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _iconColor {
    switch (_ext) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          onTap: isDownloading ? null : onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // File type icon badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: _iconColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(_fileIcon, color: _iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                // File label + name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Lampiran RPP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Download indicator: spinner while downloading, icon otherwise
                isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
