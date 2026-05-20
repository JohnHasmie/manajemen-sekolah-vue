import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_data_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_dialog_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_time_picker_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_add_edit_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_copy_dialog_mixin.dart';
import 'package:manajemensekolah/features/settings/presentation/mixins/session_ui_builder_mixin.dart';

/// Bottom sheet for managing day/session time settings.
///
/// Extracted from time_settings_screen.dart. Handles session
/// CRUD operations and displays a list of sessions for a
/// specific day with add/edit/delete/copy functionality.
class DaySessionManagementSheet extends StatefulWidget {
  final dynamic day;
  final List<dynamic> sessions;
  final Map<String, List<dynamic>> allSessionsByDay;
  final List<dynamic> allDays;
  final VoidCallback onSave;

  const DaySessionManagementSheet({
    super.key,
    required this.day,
    required this.sessions,
    required this.allSessionsByDay,
    required this.allDays,
    required this.onSave,
  });

  @override
  State<DaySessionManagementSheet> createState() =>
      _DaySessionManagementSheetState();
}

class _DaySessionManagementSheetState extends State<DaySessionManagementSheet>
    with
        SessionDataMixin,
        SessionDialogMixin,
        SessionTimePickerMixin,
        SessionAddEditMixin,
        SessionCopyDialogMixin,
        SessionUIBuilderMixin {
  late List<dynamic> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.sessions);
  }

  // Implement abstract properties and methods from mixins
  @override
  List<dynamic> get sessions => _sessions;

  @override
  set sessions(List<dynamic> value) => _sessions = value;

  @override
  Widget build(BuildContext context) {
    final dayName = dayNameToIndonesian(widget.day['name'] ?? 'Hari');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          buildHeader(dayName),
          Expanded(
            child: _sessions.isEmpty ? buildEmptyState() : buildSessionList(),
          ),
          buildFooter(),
        ],
      ),
    );
  }
}
