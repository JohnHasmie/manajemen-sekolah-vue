import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
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

  Widget buildFormHeader(Color primaryColor) {
    final subjectName = Subject.fromJson(widget.subject).name;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_chart_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Input Nilai Baru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
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

  Widget buildConfigSection(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: types.map((t) {
                final selected = t == selectedType;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setSelectedType(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? primaryColor.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? primaryColor.withValues(alpha: 0.3)
                              : ColorUtils.slate200,
                        ),
                      ),
                      child: Text(
                        typeLabels[t] ?? t.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? primaryColor : ColorUtils.slate500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final d = await showModernDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    title: 'Pilih Tanggal Penilaian',
                  );
                  if (d != null) setSelectedDate(d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(8),
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
                          fontSize: 11,
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w500,
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
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Judul (opsional)',
                    hintStyle: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate400,
                    ),
                    filled: true,
                    fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
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

  Widget buildStudentListItem(int index, Color primaryColor) {
    final student = widget.studentList[index];
    final ctrl = scoreControllers[student.id]!;
    final focusNode = scoreFocusNodes[student.id]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              student.name,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textInputAction: index < widget.studentList.length - 1
                  ? TextInputAction.next
                  : TextInputAction.done,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
              decoration: InputDecoration(
                hintText: '-',
                hintStyle: TextStyle(
                  color: ColorUtils.slate300,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ColorUtils.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              onSubmitted: (_) => focusStudent(index + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomBar(Color primaryColor) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: isSaving ? null : submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: ColorUtils.slate300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : const Text(
                    'Simpan Nilai',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
