// Stateless UI build helpers for the RPP upload-file sheet.
//
// Extracted verbatim from `_LessonPlanUploadSheetState` (Phase 2
// structural refactor) into an `extension` on the State class. Only the
// helpers that read instance state without mutating it live here — the
// header chrome and the field-label builder. They live in this `part`
// file (matching the `color_utils` part-file / `extension on X`
// pattern) so they can reference the private leaf widgets in the
// `_views` part. The chip-grid builders stay in the main State class
// because their `onSelected` callbacks call the protected `setState`,
// which an extension cannot reach.
part of 'lesson_plan_upload_sheet.dart';

extension _UploadSheetBuilders on _LessonPlanUploadSheetState {
  Widget _buildHeader(Color brand, Color brandDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandDark, brand],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => AppNavigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'RPP · EDIT FILE' : 'RPP · UPLOAD FILE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditMode
                              ? 'Edit RPP File'
                              : 'Lampirkan PDF / DOCX',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _HeaderIcon(icon: Icons.upload_rounded, onTap: null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF334155),
        letterSpacing: 0.5,
      ),
    ),
  );
}
