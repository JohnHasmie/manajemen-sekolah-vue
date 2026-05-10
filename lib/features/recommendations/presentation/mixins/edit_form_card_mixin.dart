// Edit form sect-cards — Frame E of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Each recommendation renders as a stack of brand-aligned `_SectCard`
// blocks (one per field group):
//   • Judul — violet pencil icon, "Wajib" chip, plain text input.
//   • Deskripsi — indigo bullet-list icon, "Quill" chip, AppQuillEditor.
//   • Prioritas — amber bolt icon, "Wajib" chip, 3 colored-dot chips
//     (Tinggi red / Sedang amber / Rendah slate).
//   • Materi Terkait — cobalt book icon, "n dipilih" chip, AppQuillEditor
//     per material so the wali can tweak the AI's writeup.
//
// All chrome lives inside _SectCard; the mixin only owns layout and
// state hookups. Callers wrap the whole stack in a brand page header
// + cobalt Simpan footer (see recommendation_edit_screen.dart).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';

mixin EditFormCardMixin {
  Map<String, TextEditingController> get titleControllers;
  Map<String, String> get priorities;
  Map<String, quill.QuillController> get descriptionControllers;
  Map<String, Map<String, quill.QuillController>> get materialControllers;
  BuildContext get context;
  void setState(VoidCallback fn);

  Widget buildEditCard(Map<String, dynamic> rec, int index) {
    final recId = rec['id']?.toString() ?? UniqueKey().toString();
    final cobalt = ColorUtils.brandCobalt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIndexBanner(index, rec),
          const SizedBox(height: 8),
          _SectCard(
            icon: Icons.edit_rounded,
            iconBg: ColorUtils.violet700.withValues(alpha: 0.10),
            iconFg: ColorUtils.violet700,
            title: 'Judul',
            chip: 'Wajib',
            children: [_buildTitleField(recId)],
          ),
          const SizedBox(height: 10),
          _SectCard(
            icon: Icons.description_rounded,
            iconBg: ColorUtils.indigo600.withValues(alpha: 0.10),
            iconFg: ColorUtils.indigo600,
            title: 'Deskripsi',
            chip: 'Quill',
            children: [
              if (descriptionControllers[recId] != null)
                AppQuillEditor(
                  controller: descriptionControllers[recId]!,
                  accentColor: cobalt,
                  placeholder: 'Tulis deskripsi rekomendasi...',
                  minHeight: 140,
                  maxHeight: 240,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SectCard(
            icon: Icons.flag_rounded,
            iconBg: ColorUtils.warning600.withValues(alpha: 0.10),
            iconFg: ColorUtils.warning600,
            title: 'Prioritas',
            chip: 'Wajib',
            children: [_buildPriorityRow(recId)],
          ),
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectCard(
              icon: Icons.menu_book_rounded,
              iconBg: cobalt.withValues(alpha: 0.10),
              iconFg: cobalt,
              title: 'Materi Terkait',
              chip: '${(rec['materials'] as List).length} materi',
              children: [
                for (final mat in (rec['materials'] as List))
                  _buildMaterialBlock(recId, mat as Map<String, dynamic>),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Slim banner above each rec — index + truncated title — so the
  /// teacher can tell the rec sub-stack apart when there are several
  /// in a single bulk-edit session.
  Widget _buildIndexBanner(int index, Map<String, dynamic> rec) {
    final priority =
        (priorities[rec['id']?.toString() ?? ''] ??
                rec['priority']?.toString().toLowerCase() ??
                'low')
            .toLowerCase();
    final accent = priority == 'high'
        ? ColorUtils.error600
        : priority == 'medium'
        ? ColorUtils.warning600
        : ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.06), Colors.white],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rekomendasi ${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(String recId) {
    final cobalt = ColorUtils.brandCobalt;
    return TextFormField(
      controller: titleControllers[recId],
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate900,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        hintText: 'Masukkan judul rekomendasi...',
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: ColorUtils.slate400,
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildPriorityRow(String recId) {
    final current = (priorities[recId] ?? 'low').toLowerCase();
    return Row(
      children: [
        Expanded(
          child: _PriorityChip(
            label: 'Tinggi',
            value: 'high',
            current: current,
            color: ColorUtils.error600,
            onTap: () => setState(() => priorities[recId] = 'high'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PriorityChip(
            label: 'Sedang',
            value: 'medium',
            current: current,
            color: ColorUtils.warning600,
            onTap: () => setState(() => priorities[recId] = 'medium'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PriorityChip(
            label: 'Rendah',
            value: 'low',
            current: current,
            color: ColorUtils.slate500,
            onTap: () => setState(() => priorities[recId] = 'low'),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialBlock(String recId, Map<String, dynamic> mat) {
    final matId = mat['id']?.toString() ?? UniqueKey().toString();
    final cobalt = ColorUtils.brandCobalt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cobalt.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.menu_book_rounded, size: 12, color: cobalt),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mat['title']?.toString() ?? 'Materi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (materialControllers[recId]?[matId] != null)
            AppQuillEditor(
              controller: materialControllers[recId]![matId]!,
              accentColor: cobalt,
              placeholder: 'Detail materi...',
              minHeight: 100,
              maxHeight: 180,
            ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _SectCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? chip;
  final List<Widget> children;

  const _SectCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.children,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: iconFg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color color;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.value,
    required this.current,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : ColorUtils.slate200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? color : ColorUtils.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
