// Filter bottom sheet for admin announcement screen.
// Extracted from AdminAnnouncementScreenState._showFilterSheet().
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

import 'package:manajemensekolah/features/announcements/presentation/widgets/mixins/filter_content_mixin.dart';

/// Bottom-sheet widget for filtering announcements by priority,
/// target, and status.
///
/// Like a Vue modal component that emits events back to the
/// parent: `onApply` fires when the user taps "Apply Filter".
class AnnouncementFilterSheet extends StatefulWidget {
  final String? initialPriority;
  final String? initialTarget;
  final String? initialStatus;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function(String? priority, String? target, String? status) onApply;

  const AnnouncementFilterSheet({
    super.key,
    this.initialPriority,
    this.initialTarget,
    this.initialStatus,
    required this.primaryColor,
    required this.languageProvider,
    required this.onApply,
  });

  @override
  State<AnnouncementFilterSheet> createState() =>
      _AnnouncementFilterSheetState();
}

class _AnnouncementFilterSheetState extends State<AnnouncementFilterSheet>
    with FilterContentMixin {
  String? _tempSelectedPrioritas;
  String? _tempSelectedTarget;
  String? _tempSelectedStatus;

  @override
  void initState() {
    super.initState();
    _tempSelectedPrioritas = widget.initialPriority;
    _tempSelectedTarget = widget.initialTarget;
    _tempSelectedStatus = widget.initialStatus;
  }

  @override
  String? get tempSelectedPrioritas => _tempSelectedPrioritas;

  @override
  set tempSelectedPrioritas(String? value) {
    _tempSelectedPrioritas = value;
  }

  @override
  String? get tempSelectedTarget => _tempSelectedTarget;

  @override
  set tempSelectedTarget(String? value) {
    _tempSelectedTarget = value;
  }

  @override
  String? get tempSelectedStatus => _tempSelectedStatus;

  @override
  set tempSelectedStatus(String? value) {
    _tempSelectedStatus = value;
  }

  @override
  LanguageProvider get languageProvider => widget.languageProvider;

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Announcements',
        'id': 'Filter Pengumuman',
      }),
      content: buildFilterContent(),
      primaryColor: widget.primaryColor,
      onApply: () => _onApplyPressed(context),
      onReset: _onResetPressed,
    );
  }

  void _onApplyPressed(BuildContext ctx) {
    AppNavigator.pop(ctx);
    widget.onApply(
      _tempSelectedPrioritas,
      _tempSelectedTarget,
      _tempSelectedStatus,
    );
  }

  void _onResetPressed() {
    setState(() {
      _tempSelectedPrioritas = null;
      _tempSelectedTarget = null;
      _tempSelectedStatus = null;
    });
  }
}
