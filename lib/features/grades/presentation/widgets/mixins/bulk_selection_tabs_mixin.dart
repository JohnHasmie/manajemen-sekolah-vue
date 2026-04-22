import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/bulk_selection_tab_chip.dart';

mixin BulkSelectionTabsMixin {
  String get type;
  int get tabIndex;
  List<Map<String, dynamic>> get selected;
  List<Map<String, dynamic>> get assessments;
  List<dynamic> get allAvailableChapters;
  TextEditingController get titleController;
  Color get primaryColorImpl;
  void Function(Map<String, dynamic>) get onChapterNameChanged;
  BuildContext get context;
  void setState(VoidCallback fn);

  Widget buildTabSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          BulkSelectionTabChip(
            label: 'Nama Materi',
            active: tabIndex == 0,
            color: primaryColorImpl,
            onTap: () => setState(() {}),
          ),
          const SizedBox(width: 8),
          BulkSelectionTabChip(
            label: 'Isi Otomatis',
            active: tabIndex == 1,
            color: primaryColorImpl,
            onTap: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget buildAutoFillTab() {
    if (assessments.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada riwayat nilai',
          style: TextStyle(color: ColorUtils.slate400),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: assessments.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: ColorUtils.slate100),
      itemBuilder: (_, i) => _buildAssessmentItem(assessments[i]),
    );
  }

  Widget _buildAssessmentItem(Map<String, dynamic> a) {
    final isSelected = selected.contains(a);
    final date = (a['date'] ?? '').toString();
    final dFmt = date.length >= 10
        ? '${date.substring(8, 10)}/${date.substring(5, 7)}'
        : date;

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          selected.remove(a);
        } else {
          selected.add(a);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: isSelected
            ? primaryColorImpl.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            _buildCheckBox(isSelected),
            const SizedBox(width: 12),
            _buildAssessmentLabel(a, dFmt),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckBox(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? primaryColorImpl : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? primaryColorImpl : ColorUtils.slate300,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }

  Widget _buildAssessmentLabel(Map<String, dynamic> a, String dFmt) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a['title']?.toString() ?? 'Nilai',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
            ),
          ),
          if (dFmt.isNotEmpty)
            Text(
              dFmt,
              style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
            ),
        ],
      ),
    );
  }

  Widget buildMaterialTab() {
    return Column(
      children: [
        _buildMaterialInput(),
        Divider(height: 1, color: ColorUtils.slate100),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: allAvailableChapters.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: ColorUtils.slate50),
            itemBuilder: (_, i) => _buildChapterItem(allAvailableChapters[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: titleController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Ketik nama materi...',
          hintStyle: TextStyle(fontSize: 12, color: ColorUtils.slate400),
          filled: true,
          fillColor: ColorUtils.slate50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.check, color: primaryColorImpl, size: 20),
            onPressed: _handleMaterialSubmit,
          ),
        ),
        onSubmitted: (_) => _handleMaterialSubmit(),
      ),
    );
  }

  Widget _buildChapterItem(dynamic c) {
    final title = c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        title.toString(),
        style: TextStyle(fontSize: 13, color: ColorUtils.slate800),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: ColorUtils.slate300,
      ),
      onTap: () {
        onChapterNameChanged(Map<String, dynamic>.from(c));
        Navigator.pop(context);
      },
    );
  }

  void _handleMaterialSubmit() {
    if (titleController.text.isNotEmpty) {
      onChapterNameChanged({
        'judul_bab': titleController.text,
        'judul': titleController.text,
        'title': titleController.text,
      });
      Navigator.pop(context);
    }
  }
}
