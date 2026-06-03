// Leaf presentation widgets for the RPP upload-file sheet.
//
// Extracted verbatim from `lesson_plan_upload_sheet.dart` for
// readability (Phase 2 structural refactor). These are self-contained
// `StatelessWidget`s with no coupling to `_LessonPlanUploadSheetState`,
// so they live in this `part` file while staying private to the
// upload-sheet library (matching the `color_utils` part-file pattern).
part of 'lesson_plan_upload_sheet.dart';

/// Slate-tinted hint rendered in place of an empty `FilterChipGrid` so
/// the form keeps its rhythm even when a dependent list is locked or
/// hasn't loaded yet.
class _ChipPlaceholder extends StatelessWidget {
  const _ChipPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const slate100 = Color(0xFFF1F5F9);
    const slate300 = Color(0xFFCBD5E1);
    const slate500 = Color(0xFF64748B);
    const slate900 = Color(0xFF0F172A);
    const cobalt = Color(0xFF1B6FB8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC), // slate-50
            border: Border.all(
              color: slate300,
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: slate100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 20,
                  color: cobalt,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pilih file dari perangkat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PDF, DOC, DOCX · Maks 10 MB',
                style: TextStyle(fontSize: 11, color: slate500, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cobalt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Pilih file',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({
    required this.fileName,
    required this.fileSize,
    required this.isUploading,
    required this.onRemove,
    this.isReplacement = false,
  });

  final String fileName;
  final int fileSize;
  final bool isUploading;
  final VoidCallback? onRemove;

  /// Edit-mode flag — tints the card emerald and adds a `BARU` chip
  /// so the teacher can see at a glance this is the replacement file.
  final bool isReplacement;

  String get _humanSize {
    if (fileSize <= 0) return '-';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    const red50 = Color(0xFFFEE2E2);
    const red600 = Color(0xFFB91C1C);
    const slate100 = Color(0xFFF1F5F9);
    const slate200 = Color(0xFFE2E8F0);
    const slate500 = Color(0xFF64748B);
    const slate900 = Color(0xFF0F172A);
    const green50 = Color(0xFFDCFCE7);
    const green600 = Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReplacement ? green50.withValues(alpha: 0.45) : Colors.white,
        border: Border.all(
          color: isReplacement ? green600 : slate200,
          width: isReplacement ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: red50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 20,
              color: red600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReplacement)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: green600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BARU',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isUploading
                      ? '$_humanSize · mengunggah…'
                      : (isReplacement
                            ? '$_humanSize · siap diunggah'
                            : _humanSize),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isReplacement ? green600 : slate500,
                  ),
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: red600),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              style: IconButton.styleFrom(
                backgroundColor: slate100,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.placeholder,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Existing-file card shown in edit mode when no replacement has
/// been picked yet. The single primary action is "Ganti file" — tap
/// opens the picker and the card morphs into the [_SelectedFileCard]
/// with `isReplacement: true`.
class _ExistingFileCard extends StatelessWidget {
  const _ExistingFileCard({
    required this.fileName,
    required this.fileSize,
    required this.onReplace,
    required this.accent,
  });

  final String fileName;
  final int fileSize;
  final VoidCallback onReplace;
  final Color accent;

  String get _humanSize {
    if (fileSize <= 0) return 'file saat ini';
    if (fileSize < 1024) return '$fileSize B · file saat ini';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB · file saat ini';
    }
    final mb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB · file saat ini';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 18,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _humanSize,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: accent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onReplace,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Ganti file',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Old-file warning shown beneath the new [_SelectedFileCard] when a
/// teacher has picked a replacement during edit mode. Greyed out,
/// dashed border, single line — purely informational so the teacher
/// can confirm what's about to be removed.
class _OldFileWarning extends StatelessWidget {
  const _OldFileWarning({required this.fileName, required this.fileSize});

  final String fileName;
  final int fileSize;

  String get _humanSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return ' · $fileSize B';
    if (fileSize < 1024 * 1024) {
      return ' · ${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return ' · ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'Akan diganti: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '$fileName$_humanSize'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
