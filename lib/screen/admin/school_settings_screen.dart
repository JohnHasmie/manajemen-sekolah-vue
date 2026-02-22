import 'package:flutter/material.dart';
import 'package:manajemensekolah/screen/admin/school_level_settings_screen.dart';
import 'package:manajemensekolah/screen/admin/time_settings_screen.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final menuItems = [
      _MenuItem(
        title: AppLocalizations.generalSettings.tr,
        subtitle: 'Jenjang & informasi sekolah',
        icon: Icons.school_rounded,
        color: ColorUtils.getColorForIndex(0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SchoolLevelSettingsScreen()),
        ),
      ),
      _MenuItem(
        title: AppLocalizations.timeSettings.tr,
        subtitle: 'Jadwal & waktu pembelajaran',
        icon: Icons.access_time_rounded,
        color: ColorUtils.getColorForIndex(2),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TimeSettingsScreen()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Custom Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.corporateBlue600,
                  ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.getTranslatedText(AppLocalizations.schoolSettings),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kelola pengaturan sekolah',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body content
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.corporateBlue600.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: ColorUtils.corporateBlue600,
                              size: 17,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            lang.getTranslatedText(
                              AppLocalizations.settingsMenu,
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) =>
                          _buildMenuCard(menuItems[index]),
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

  Widget _buildMenuCard(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: ColorUtils.slate500,
                      size: 18,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                item.subtitle,
                style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
