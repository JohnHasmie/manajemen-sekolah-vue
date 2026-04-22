import 'package:flutter/material.dart';

mixin BulkSelectionHeaderMixin {
  String get type;
  int? get chapterIndex;
  Color get primaryColorImpl;
  BuildContext get context;

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
      decoration: _buildHeaderDecoration(),
      child: Column(children: [_buildDragHandle(), _buildHeaderContent()]),
    );
  }

  BoxDecoration _buildHeaderDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColorImpl, primaryColorImpl.withValues(alpha: 0.85)],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _buildHeaderTitle(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  String _buildHeaderTitle() {
    if (type == 'bab') {
      return 'Pengaturan Bab ${(chapterIndex ?? 0) + 1}';
    }
    return 'Pengaturan ${type.toUpperCase()}';
  }
}
