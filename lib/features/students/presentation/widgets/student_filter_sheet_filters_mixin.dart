import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet_content.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

/// Mixin providing filter section builders for StudentFilterSheetContent.
///
/// Organizes UI construction for four filter types: guardian, status,
/// class, and gender.
mixin StudentFilterSheetFiltersMixin on State<StudentFilterSheetContent> {
  // Abstract accessors for state fields defined in the mixing class.
  String? get tempStatus;
  List<String> get tempClassIds;
  String? get tempGender;
  String? get tempGuardian;

  void updateStatus(String? value);
  void updateGender(String? value);
  void updateGuardian(String? value);
  void toggleClassId(String classId);
  void updateClassIds(List<String> values);

  Widget buildGuardianFilter(
    BuildContext context,
    String Function(Map<String, String> translations) t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: t({'en': 'Guardian Name', 'id': 'Nama Wali Murid'}),
          icon: Icons.family_restroom_rounded,
          primaryColor: widget.primaryColor,
        ),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.length < 2) {
              return const Iterable<String>.empty();
            }
            return await getIt<ApiStudentService>().getGuardians(
              textEditingValue.text,
            );
          },
          onSelected: updateGuardian,
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                if (tempGuardian != null &&
                    textEditingController.text.isEmpty) {
                  textEditingController.text = tempGuardian!;
                }
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: t({
                      'en': 'Search Guardian',
                      'id': 'Cari Wali Murid',
                    }),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.person_search_rounded,
                      color: ColorUtils.slate400,
                    ),
                    suffixIcon: tempGuardian != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              textEditingController.clear();
                              updateGuardian(null);
                            },
                          )
                        : null,
                  ),
                );
              },
        ),
      ],
    );
  }

  Widget buildStatusFilter(
    BuildContext context,
    String Function(Map<String, String> translations) t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: t({'en': 'Status', 'id': 'Status'}),
          icon: Icons.check_circle_outline_rounded,
          primaryColor: widget.primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(value: null, label: t({'en': 'All', 'id': 'Semua'})),
            FilterOption(
              value: 'active',
              label: t({'en': 'Active', 'id': 'Aktif'}),
            ),
            FilterOption(
              value: 'inactive',
              label: t({'en': 'Inactive', 'id': 'Tidak Aktif'}),
            ),
          ],
          selectedValue: tempStatus,
          onSelected: updateStatus,
          selectedColor: widget.primaryColor,
        ),
      ],
    );
  }

  Widget buildClassFilter(
    BuildContext context,
    String Function(Map<String, String> translations) t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: t({'en': 'Class', 'id': 'Kelas'}),
          icon: Icons.school_outlined,
          primaryColor: widget.primaryColor,
        ),
        FilterChipGrid<String>(
          options: widget.classList.map((classItem) {
            final model = Classroom.fromJson(classItem as Map<String, dynamic>);
            return FilterOption(value: model.id, label: model.name);
          }).toList(),
          multiSelect: true,
          selectedValues: tempClassIds.toSet(),
          onMultiSelected: (values) => updateClassIds(values.toList()),
          selectedColor: widget.primaryColor,
        ),
      ],
    );
  }

  Widget buildGenderFilter(
    BuildContext context,
    String Function(Map<String, String> translations) t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionHeader(
          title: t({'en': 'Gender', 'id': 'Jenis Kelamin'}),
          icon: Icons.transgender_rounded,
          primaryColor: widget.primaryColor,
        ),
        FilterChipGrid<String?>(
          options: [
            FilterOption(value: null, label: t({'en': 'All', 'id': 'Semua'})),
            // Backend canonical: `male` / `female` (was `L` / `P`).
            FilterOption(
              value: 'male',
              label: t({'en': 'Male', 'id': 'Laki-laki'}),
            ),
            FilterOption(
              value: 'female',
              label: t({'en': 'Female', 'id': 'Perempuan'}),
            ),
          ],
          selectedValue: tempGender,
          onSelected: updateGender,
          selectedColor: widget.primaryColor,
        ),
      ],
    );
  }
}
