import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ScheduleFormHeader extends StatelessWidget {
  final bool isEdit;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const ScheduleFormHeader({
    super.key,
    required this.isEdit,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final title = isEdit
        ? languageProvider.getTranslatedText({
            'en': 'Edit Schedule',
            'id': 'Edit Jadwal',
          })
        : languageProvider.getTranslatedText({
            'en': 'Add Schedule',
            'id': 'Tambah Jadwal',
          });
    final subtitle = isEdit
        ? languageProvider.getTranslatedText({
            'en': 'Update schedule information',
            'id': 'Perbarui informasi jadwal',
          })
        : languageProvider.getTranslatedText({
            'en': 'Fill in the schedule information',
            'id': 'Isi informasi jadwal',
          });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.82)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              isEdit ? Icons.edit_calendar_outlined : Icons.add_chart,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
