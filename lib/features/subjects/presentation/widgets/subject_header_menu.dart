import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Subject header menu widget with export/import/refresh options.
class SubjectHeaderMenu extends ConsumerWidget {
  final GlobalKey menuKey;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onExport;
  final Future<void> Function() onImport;
  final Future<void> Function() onTemplate;

  const SubjectHeaderMenu({
    super.key,
    required this.menuKey,
    required this.onRefresh,
    required this.onExport,
    required this.onImport,
    required this.onTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    return PopupMenuButton<String>(
      key: menuKey,
      onSelected: (value) async {
        switch (value) {
          case 'refresh':
            await onRefresh();
            break;
          case 'export':
            await onExport();
            break;
          case 'import':
            await onImport();
            break;
          case 'template':
            await onTemplate();
            break;
        }
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Refresh Data',
                  'id': 'Perbarui Data',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Export to Excel',
                  'id': 'Export ke Excel',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'import',
          child: Row(
            children: [
              const Icon(Icons.upload, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Import from Excel',
                  'id': 'Import dari Excel',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'template',
          child: Row(
            children: [
              const Icon(Icons.file_download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Download Template',
                  'id': 'Download Template',
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
