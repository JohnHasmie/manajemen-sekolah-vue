import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_input_dialog.dart';

/// Mixin for grade input form UI building.
mixin GradeInputUiBuilderMixin on State<GradeInputDialog> {
  // Abstract getters/setters from form mixin
  String get selectedType;
  DateTime get selectedDate;
  TextEditingController get titleController;
  Map<String, String> get typeLabels;
  List<String> get types;
  bool get isSaving;

  // State-held controllers/focus nodes (not on widget).
  Map<String, TextEditingController> get scoreControllers;
  Map<String, FocusNode> get scoreFocusNodes;

  void setSelectedType(String type);
  void setSelectedDate(DateTime date);
  String formatDate(DateTime d);
  void focusStudent(int index);
  Future<void> submit();

  /// Brand-aligned cobalt header — mirrors the shape that
  /// `BrandPageHeader` paints on full-page screens (RPP / Presensi
  /// / Kegiatan Kelas). Drag handle inlined into the gradient so the
  /// cobalt reaches the rounded top edge with no white strip.
  /// Centered kicker + title pattern matches the rest of the
  /// teacher chrome.
  Widget buildFormHeader(Color primaryColor) {
    final subjectName = Subject.fromJson(widget.subject).name;
    final cobaltDark =
        Color.lerp(primaryColor, Colors.black, 0.18) ?? primaryColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cobaltDark, primaryColor],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        children: [
          // Drag handle inside the gradient so the cobalt reaches
          // the rounded edge — no white strip between the sheet
          // top and the header.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${kGraBookLabel.tr} · ${subjectName.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kGraNewGradeEntryTitle.tr,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildConfigSection(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type chips — Frame E styling: active chips fill cobalt
          // with white text + soft cobalt shadow so the active type
          // jumps out at a glance. Replaces the legacy outline-tint
          // (low contrast).
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: types.map((t) {
                final selected = t == selectedType;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setSelectedType(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected ? primaryColor : ColorUtils.slate200,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.22),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        typeLabels[t] ?? t.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : ColorUtils.slate600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Date + Judul row — Frame E styling: cobalt-tinted date
          // chip with calendar icon, taller title field, both with
          // 10px radius matching the type chip pill family.
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final d = await showModernDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    title: kGraSelectAssessmentDate.tr,
                  );
                  if (d != null) setSelectedDate(d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDate(selectedDate),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: titleController,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ColorUtils.slate900,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: kGraTitleOptional.tr,
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      color: ColorUtils.slate400,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primaryColor, width: 1.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Frame B per-student input row — avatar + name + NIS + 92×56
  /// score box. State-aware tinting: empty rows stay white-on-slate,
  /// filled rows tint cobalt (no KKM data yet), green when score is
  /// ≥ 75 (KKM), red when below. Avatar tints red on under-KKM rows
  /// so the warning is visible even when the score box scrolls off
  /// or is being edited.
  Widget buildStudentListItem(int index, Color primaryColor) {
    final student = widget.studentList[index];
    final ctrl = scoreControllers[student.id]!;
    final focusNode = scoreFocusNodes[student.id]!;
    final hasValue = ctrl.text.trim().isNotEmpty;
    final score = double.tryParse(ctrl.text.trim());
    final isOverKkm = score != null && score >= 75;
    final isUnderKkm = score != null && score < 75;

    // Pick a row tint based on the score state.
    final Color rowBg;
    final Color rowBorder;
    final List<BoxShadow>? rowShadow;
    if (isOverKkm) {
      rowBg = ColorUtils.success600.withValues(alpha: 0.06);
      rowBorder = ColorUtils.success600.withValues(alpha: 0.30);
      rowShadow = [
        BoxShadow(
          color: ColorUtils.success600.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isUnderKkm) {
      rowBg = ColorUtils.error600.withValues(alpha: 0.06);
      rowBorder = ColorUtils.error600.withValues(alpha: 0.30);
      rowShadow = [
        BoxShadow(
          color: ColorUtils.error600.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (hasValue) {
      rowBg = primaryColor.withValues(alpha: 0.04);
      rowBorder = primaryColor.withValues(alpha: 0.30);
      rowShadow = [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      rowBg = Colors.white;
      rowBorder = ColorUtils.slate200;
      rowShadow = null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rowBorder),
        boxShadow: rowShadow,
      ),
      child: Row(
        children: [
          // Avatar — tints red on under-KKM rows so the warning is
          // visible at a glance even before the teacher reads the
          // score. Otherwise cobalt-tinted matching the rest of the
          // teacher tools.
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isUnderKkm
                  ? ColorUtils.error600.withValues(alpha: 0.12)
                  : primaryColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFor(student.name),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isUnderKkm ? ColorUtils.error600 : primaryColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + NIS column.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (student.studentNumber.isNotEmpty)
                  Text(
                    student.studentNumber,
                    style: TextStyle(
                      fontSize: 10,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 92×56 score box — state-aware fill (slate empty / cobalt
          // filled / green over-KKM / red under-KKM). Big 22pt 900
          // score number with `/ 100` denominator caption when
          // filled. Empty state shows cobalt edit icon + uppercase
          // "Nilai" hint behind an IgnorePointer so the tap still
          // focuses the input.
          _buildScoreBox(
            ctrl: ctrl,
            focusNode: focusNode,
            hasValue: hasValue,
            isOverKkm: isOverKkm,
            isUnderKkm: isUnderKkm,
            primaryColor: primaryColor,
            onSubmittedNext: () => focusStudent(index + 1),
            isLast: index >= widget.studentList.length - 1,
          ),
        ],
      ),
    );
  }

  /// State-aware 92×56 score box. Cobalt-tinted by default, green
  /// when the score is ≥75, red when below. Empty state shows a
  /// cobalt edit icon + "NILAI" hint behind an IgnorePointer so taps
  /// still focus the field. Enter advances to the next student via
  /// `onSubmittedNext` (`focusStudent(index + 1)`).
  Widget _buildScoreBox({
    required TextEditingController ctrl,
    required FocusNode focusNode,
    required bool hasValue,
    required bool isOverKkm,
    required bool isUnderKkm,
    required Color primaryColor,
    required VoidCallback onSubmittedNext,
    required bool isLast,
  }) {
    Color fillColor;
    Color borderColor;
    Color numberColor;
    if (isOverKkm) {
      fillColor = ColorUtils.success600.withValues(alpha: 0.10);
      borderColor = ColorUtils.success600.withValues(alpha: 0.45);
      numberColor = ColorUtils.success600;
    } else if (isUnderKkm) {
      fillColor = ColorUtils.error600.withValues(alpha: 0.10);
      borderColor = ColorUtils.error600.withValues(alpha: 0.45);
      numberColor = ColorUtils.error600;
    } else if (hasValue) {
      fillColor = primaryColor.withValues(alpha: 0.10);
      borderColor = primaryColor.withValues(alpha: 0.45);
      numberColor = primaryColor;
    } else {
      fillColor = ColorUtils.slate50;
      borderColor = ColorUtils.slate200;
      numberColor = ColorUtils.slate900;
    }
    // "Nilai" placeholder uses the TextField's native hintText
    // (instead of an IgnorePointer overlay) so it lays out exactly
    // like the score number — same TextField → same baseline → no
    // centering drift. The overlay approach was anchoring at the
    // top of the Stack despite Positioned.fill + Center, because
    // the SizedBox-Stack sequence doesn't always propagate full
    // bounds to nested Center widgets.
    return SizedBox(
      width: 92,
      height: 56,
      child: Stack(
        children: [
          Positioned.fill(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textInputAction: isLast
                  ? TextInputAction.done
                  : TextInputAction.next,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: numberColor,
                letterSpacing: -0.5,
                height: 1.0,
              ),
              decoration: InputDecoration(
                hintText: focusNode.hasFocus ? '' : kGraScore.tr,
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryColor.withValues(alpha: 0.50),
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
                filled: true,
                fillColor: fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onChanged: (_) {
                // Trigger a rebuild so the row + score box pick up
                // the new state-aware tinting (filled / over / under
                // KKM) immediately as the teacher types.
                setState(() {});
              },
              onSubmitted: (_) {
                // Enter / Next — move keyboard focus to the next
                // student's score box. The `focusStudent(index + 1)`
                // helper from the form mixin handles the iteration
                // so the teacher can crank through a class without
                // taking their hands off the keyboard.
                onSubmittedNext();
              },
            ),
          ),
          // "/ 100" denominator caption — only when filled, sits at
          // the bottom edge of the box.
          if (hasValue)
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate400,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 1-2 character initials helper for the avatar circles. Mirrors
  /// the helper inside `student_card_list_widget.dart`. Picks the
  /// first letter of the first two whitespace-separated tokens; falls
  /// back to the first two letters of the trimmed name; falls back
  /// to "?" for empty.
  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Frame B footer — progress bar + dynamic "Simpan N" button. The
  /// teacher always sees how many cells are filled out of total, plus
  /// how many remain. Replaces the legacy full-width "Simpan Nilai"
  /// button.
  Widget buildBottomBar(Color primaryColor) {
    final filled = scoreControllers.values
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    final total = widget.studentList.length;
    final remaining = total - filled;
    final progress = total == 0 ? 0.0 : filled / total;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
        ),
        child: Row(
          children: [
            // Progress strip — slate track + cobalt fill + count text.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: ColorUtils.slate100,
                      valueColor: AlwaysStoppedAnimation(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$filled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: ColorUtils.slate900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        '/$total',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate400,
                        ),
                      ),
                      if (remaining > 0) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: ColorUtils.slate300,
                          ),
                        ),
                        Text(
                          '$remaining belum',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // CTA — "Simpan 3" / "Simpan Nilai" / spinner. Disables
            // when no rows have a value yet so a stray tap doesn't
            // POST an empty payload.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (isSaving || filled == 0) ? null : submit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: filled == 0 ? ColorUtils.slate200 : primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: filled == 0
                        ? null
                        : [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: filled == 0
                                  ? ColorUtils.slate400
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              filled == 0 ? kSave.tr : '${kSave.tr} $filled',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: filled == 0
                                    ? ColorUtils.slate400
                                    : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
