// Mixin for building edit form cards and quill editor sections.
// Redesigned with professional UI: focused edit mode per recommendation,
// polished Quill toolbar, section separators, and refined typography.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';

/// Mixin for building form cards and quill editor sections.
mixin EditFormCardMixin {
  Map<String, TextEditingController> get titleControllers;
  Map<String, String> get priorities;
  Map<String, quill.QuillController> get descriptionControllers;
  Map<String, Map<String, quill.QuillController>> get materialControllers;
  BuildContext get context;
  void setState(VoidCallback fn);

  Color get _editAccent =>
      ColorUtils.getRoleColor('guru');

  /// Builds edit card for a single recommendation.
  Widget buildEditCard(Map<String, dynamic> rec, int index) {
    final recId = rec['id']?.toString() ?? UniqueKey().toString();
    final priority = priorities[recId] ?? 'low';

    // Accent color per priority
    final Color accentColor;
    if (priority == 'high') {
      accentColor = ColorUtils.red500;
    } else if (priority == 'medium') {
      accentColor = ColorUtils.amber500;
    } else {
      accentColor = ColorUtils.corporateBlue500;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header with accent strip
          _buildCardHeader(index, accentColor),

          // Title section
          _buildFormSection(
            icon: Icons.title_rounded,
            label: 'Judul Rekomendasi',
            child: _buildTitleField(recId),
          ),

          _sectionDivider(),

          // Priority section
          _buildFormSection(
            icon: Icons.flag_rounded,
            label: 'Prioritas',
            child: _buildPrioritySelector(recId),
          ),

          _sectionDivider(),

          // Description editor section
          _buildFormSection(
            icon: Icons.description_rounded,
            label: 'Deskripsi Rekomendasi',
            child: descriptionControllers[recId] != null
                ? _buildQuillSection(descriptionControllers[recId]!)
                : const SizedBox.shrink(),
          ),

          // Materials section
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            _sectionDivider(),
            _buildMaterialsSection(rec, recId),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCardHeader(int index, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            accentColor.withValues(alpha: 0.06),
            Colors.white,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: ColorUtils.slate100),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rekomendasi ${index + 1}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: ColorUtils.slate400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(icon, size: 14, color: _editAccent.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _sectionDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: ColorUtils.slate100,
    );
  }

  Widget _buildTitleField(String recId) {
    return TextFormField(
      controller: titleControllers[recId],
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ColorUtils.slate800,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        hintText: 'Masukkan judul rekomendasi...',
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ColorUtils.slate400,
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _editAccent.withValues(alpha: 0.5), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildPrioritySelector(String recId) {
    final currentPriority = priorities[recId] ?? 'low';

    return Row(
      children: [
        _buildPriorityChip(
          recId,
          'low',
          'Rendah',
          Icons.arrow_downward_rounded,
          ColorUtils.corporateBlue500,
          currentPriority,
        ),
        const SizedBox(width: 8),
        _buildPriorityChip(
          recId,
          'medium',
          'Sedang',
          Icons.remove_rounded,
          ColorUtils.amber500,
          currentPriority,
        ),
        const SizedBox(width: 8),
        _buildPriorityChip(
          recId,
          'high',
          'Tinggi',
          Icons.priority_high_rounded,
          ColorUtils.red500,
          currentPriority,
        ),
      ],
    );
  }

  Widget _buildPriorityChip(
    String recId,
    String value,
    String label,
    IconData icon,
    Color color,
    String current,
  ) {
    final isSelected = current == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => priorities[recId] = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: isSelected ? color : ColorUtils.slate200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : ColorUtils.slate400,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : ColorUtils.slate500,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsSection(Map<String, dynamic> rec, String recId) {
    final materials = rec['materials'] as List;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: _editAccent.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Materi & Aktivitas (${materials.length})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...materials.map((mat) => _buildMaterialItem(recId, mat)),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(String recId, Map<String, dynamic> mat) {
    final matId = mat['id']?.toString() ?? UniqueKey().toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Material title
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _editAccent.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: _editAccent.withValues(alpha: 0.5),
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mat['title'] ?? 'Materi',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (materialControllers[recId]?[matId] != null)
            _buildQuillSection(materialControllers[recId]![matId]!),
        ],
      ),
    );
  }

  /// Builds Quill editor section using the shared AppQuillEditor component.
  Widget _buildQuillSection(quill.QuillController controller) {
    return AppQuillEditor(
      controller: controller,
      accentColor: _editAccent,
      placeholder: 'Tulis konten...',
      minHeight: 120,
      maxHeight: 200,
    );
  }
}
