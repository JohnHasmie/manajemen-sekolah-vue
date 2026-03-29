// Extracted from teacher_attendance_screen.dart (_buildHeader +
// _buildModeSwitcher). Like a Vue `<AttendanceTeacherHeader>` component --
// renders the gradient header with back button, title, refresh menu, and the
// tab switcher bar that lives at the bottom of the header.
//
// Stateless: navigation and refresh are handled by callbacks passed from the
// parent. The TabController is owned by the parent and passed in as a prop,
// mirroring how Vue passes reactive data down via props.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/tab_switcher.dart';

/// Gradient header for the teacher attendance screen with a mode-switching
/// tab bar at the bottom.
///
/// Parameters (like Vue props / emits):
/// - [tabController]      -- controls which tab is active (owned by parent)
/// - [tabSwitcherKey]     -- GlobalKey for the tour highlight on the tab bar
/// - [primaryColor]       -- role-based accent color
/// - [gradient]           -- background gradient derived from primaryColor
/// - [currentTabIndex]    -- current tab index (0 = Results, 1 = Input)
/// - [hasClassSelected]   -- whether a class is currently selected; controls
///                           the back-button behaviour (deselect vs. pop route)
/// - [languageProvider]   -- for translating UI strings
/// - [onBack]             -- called when the back button is tapped; parent
///                           decides whether to deselect class or pop the page
/// - [onRefresh]          -- called when "Perbarui Data" menu item is chosen
class AttendanceTeacherHeader extends StatelessWidget {
  final TabController tabController;
  final GlobalKey tabSwitcherKey;
  final Color primaryColor;
  final LinearGradient gradient;
  final int currentTabIndex;
  final bool hasClassSelected;
  final LanguageProvider languageProvider;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const AttendanceTeacherHeader({
    super.key,
    required this.tabController,
    required this.tabSwitcherKey,
    required this.primaryColor,
    required this.gradient,
    required this.currentTabIndex,
    required this.hasClassSelected,
    required this.languageProvider,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back / deselect button
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title + subtitle column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTabIndex == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Attendance Results',
                              'id': 'Hasil Absensi',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Add Attendance',
                              'id': 'Tambah Absensi',
                            }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentTabIndex == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'View attendance records',
                              'id': 'Lihat catatan kehadiran',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Record student attendance',
                              'id': 'Catat kehadiran siswa',
                            }),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Three-dot overflow menu (refresh action)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') onRefresh();
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: ColorUtils.info600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Perbarui Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Mode switcher (tab bar) embedded at the bottom of the header.
          // Wrapped in a Container so the tour can attach a GlobalKey to it.
          Container(
            key: tabSwitcherKey,
            margin: const EdgeInsets.all(AppSpacing.lg),
            child: TabSwitcher(
              tabController: tabController,
              primaryColor: primaryColor,
              tabs: [
                TabItem(
                  label: languageProvider.getTranslatedText({
                    'en': 'Attendance Results',
                    'id': 'Hasil Absensi',
                  }),
                  icon: Icons.list_alt,
                ),
                TabItem(
                  label: languageProvider.getTranslatedText({
                    'en': 'Add Attendance',
                    'id': 'Tambah Absensi',
                  }),
                  icon: Icons.add_circle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
