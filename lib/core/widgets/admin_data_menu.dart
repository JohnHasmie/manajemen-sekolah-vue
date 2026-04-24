// Shared overflow menu for admin CRUD data screens.
//
// Why this exists
// ---------------
// Every admin CRUD screen (Siswa, Guru, Kelas, Mapel, Jadwal, …) ships the
// same four-item popup menu in the header trailing slot: Refresh · Export
// to Excel · Import from Excel · Download Template. Each screen today
// reimplements ~60 lines of identical `PopupMenuButton` scaffolding with
// slightly different copy.
//
// `AdminDataMenu` factors that menu out. Callers only pass the handlers
// (nullable — a null handler omits the corresponding item) plus the
// language provider for translation. The widget handles the circular
// white-on-dark icon shell, the `on dark surface` color scheme, and the
// menu item layout.
//
// Typical use inside [AdminCrudScaffold.actionMenu]:
// ```dart
// AdminCrudScaffold(
//   actionMenu: AdminDataMenu(
//     languageProvider: lang,
//     onRefresh: _refresh,
//     onExport: _exportExcel,
//     onImport: _importExcel,
//     onDownloadTemplate: _downloadTemplate,
//   ),
//   ...
// );
// ```
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Overflow "kebab" menu for admin CRUD screens.
///
/// Renders a 40×40 white-on-accent circle with a vertical ellipsis icon,
/// and opens a four-entry popup: Refresh · Export · Import · Template.
/// Each entry is skipped when its callback is null, so screens without a
/// template or import flow (e.g., Mapel) only show the items they support.
class AdminDataMenu extends StatelessWidget {
  /// Provides Bahasa Indonesia / English copy for menu items.
  final LanguageProvider languageProvider;

  /// Refresh-data handler. When null, the refresh item is hidden.
  final VoidCallback? onRefresh;

  /// Export-to-Excel handler. When null, the export item is hidden.
  final VoidCallback? onExport;

  /// Import-from-Excel handler. When null, the import item is hidden.
  final VoidCallback? onImport;

  /// Download-template handler. When null, the template item is hidden.
  final VoidCallback? onDownloadTemplate;

  /// Tooltip shown on long-press of the trigger button.
  final String tooltip;

  /// Optional key used by tutorial-coach-mark targeting.
  final Key? triggerKey;

  const AdminDataMenu({
    super.key,
    required this.languageProvider,
    this.onRefresh,
    this.onExport,
    this.onImport,
    this.onDownloadTemplate,
    this.tooltip = 'Menu',
    this.triggerKey,
  });

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuEntry<_AdminMenuAction>>[];

    if (onRefresh != null) {
      items.add(
        PopupMenuItem<_AdminMenuAction>(
          value: _AdminMenuAction.refresh,
          child: _MenuRow(
            icon: Icons.refresh,
            iconColor: ColorUtils.info600,
            label: languageProvider.getTranslatedText(const {
              'en': 'Refresh Data',
              'id': 'Perbarui Data',
            }),
          ),
        ),
      );
    }

    if (onExport != null) {
      items.add(
        PopupMenuItem<_AdminMenuAction>(
          value: _AdminMenuAction.export,
          child: _MenuRow(
            icon: Icons.download,
            label: languageProvider.getTranslatedText(const {
              'en': 'Export to Excel',
              'id': 'Export ke Excel',
            }),
          ),
        ),
      );
    }

    if (onImport != null) {
      items.add(
        PopupMenuItem<_AdminMenuAction>(
          value: _AdminMenuAction.import,
          child: _MenuRow(
            icon: Icons.upload,
            label: languageProvider.getTranslatedText(const {
              'en': 'Import from Excel',
              'id': 'Import dari Excel',
            }),
          ),
        ),
      );
    }

    if (onDownloadTemplate != null) {
      items.add(
        PopupMenuItem<_AdminMenuAction>(
          value: _AdminMenuAction.template,
          child: _MenuRow(
            icon: Icons.file_download,
            label: languageProvider.getTranslatedText(const {
              'en': 'Download Template',
              'id': 'Download Template',
            }),
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<_AdminMenuAction>(
      key: triggerKey,
      tooltip: tooltip,
      onSelected: _handleSelection,
      itemBuilder: (_) => items,
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
    );
  }

  void _handleSelection(_AdminMenuAction action) {
    switch (action) {
      case _AdminMenuAction.refresh:
        onRefresh?.call();
        break;
      case _AdminMenuAction.export:
        onExport?.call();
        break;
      case _AdminMenuAction.import:
        onImport?.call();
        break;
      case _AdminMenuAction.template:
        onDownloadTemplate?.call();
        break;
    }
  }
}

/// Typed enum for the four menu actions. Private to this file.
enum _AdminMenuAction { refresh, export, import, template }

/// Icon + label row used inside each [PopupMenuItem].
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;

  const _MenuRow({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}
