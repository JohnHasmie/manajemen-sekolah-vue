// Extracted from admin_attendance_report_screen.dart (_buildClassList).
// Like a Vue `<AttendanceClassListView>` component -- renders either a
// skeleton loader, an empty state, or a scrollable list of classes that
// the admin can tap to drill into attendance data.
//
// Stateless: all mutable data and callbacks are passed in as constructor
// parameters (like Vue props + emits). In Laravel terms, this is a Blade
// partial that reads data from a passed-in collection variable and
// fires events back to the parent.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

/// Renders the class-selection list for the admin attendance report screen.
///
/// Parameters (like Vue props):
/// - [isLoading]        -- shows a skeleton list while classes are being fetched
/// - [classList]        -- the full list of class objects (from the API)
/// - [searchTerm]       -- current search filter value (lower-cased by the parent)
/// - [primaryColor]     -- role-based accent color
/// - [languageProvider] -- for translating UI strings
/// - [onRefresh]        -- called on pull-to-refresh
/// - [onClassSelected]  -- called when the user taps a class item, passing the
///                         raw class Map back to the parent
class AttendanceClassListView extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> classList;
  final String searchTerm;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic> classItem) onClassSelected;

  const AttendanceClassListView({
    super.key,
    required this.isLoading,
    required this.classList,
    required this.searchTerm,
    required this.primaryColor,
    required this.languageProvider,
    required this.onRefresh,
    required this.onClassSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Show skeleton while the class list is loading from the API.
    if (isLoading) {
      return SkeletonListLoading(
        itemCount: 8,
        infoTagCount: 1,
        showActions: false,
      );
    }

    // Filter classes client-side based on the search term.
    final filteredClasses = classList.where((cls) {
      final className = cls['name']?.toString().toLowerCase() ?? '';
      return className.contains(searchTerm);
    }).toList();

    // Empty state — shown when no class matches the search.
    if (filteredClasses.isEmpty) {
      return Center(
        child: Text(
          languageProvider.getTranslatedText({
            'en': 'No classes found',
            'id': 'Tidak ada data kelas',
          }),
          style: TextStyle(color: ColorUtils.slate400),
        ),
      );
    }

    // Scrollable list of class cards with pull-to-refresh support.
    // Like a Vue `<ul v-for="cls in filteredClasses">` with a refresh trigger.
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredClasses.length,
        itemBuilder: (context, index) {
          final classItem = filteredClasses[index] as Map<String, dynamic>;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onClassSelected(classItem),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.class_,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classItem['name'] ?? 'Unknown Class',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat'})}: ${classItem['grade_level'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: ColorUtils.slate400,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
