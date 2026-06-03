// Edit form sect-cards — Frame E of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Each recommendation renders as a stack of brand-aligned
// `RecEditSectCard` blocks (one per field group):
//   • Judul — violet pencil icon, "Wajib" chip, plain text input.
//   • Deskripsi — indigo bullet-list icon, "Quill" chip, AppQuillEditor.
//   • Prioritas — amber bolt icon, "Wajib" chip, 3 colored-dot chips
//     (Tinggi red / Sedang amber / Rendah slate).
//   • Materi Terkait — cobalt book icon, "n dipilih" chip, AppQuillEditor
//     per material so the wali can tweak the AI's writeup.
//
// All chrome lives inside RecEditSectCard; the mixin only owns layout and
// state hookups. Callers wrap the whole stack in a brand page header
// + cobalt Simpan footer (see recommendation_edit_screen.dart).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_add_material_sheet.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_edit_form_widgets.dart';

mixin EditFormCardMixin {
  Map<String, TextEditingController> get titleControllers;
  Map<String, String> get priorities;
  Map<String, quill.QuillController> get descriptionControllers;
  Map<String, Map<String, quill.QuillController>> get materialControllers;
  BuildContext get context;
  void setState(VoidCallback fn);

  /// "Catatan Wali Kelas" textarea — single per-rec controller fed
  /// in by the screen state. Empty when the rec has no
  /// `teacher_notes` value.
  TextEditingController get notesController;

  /// Live list of material chips shown under "Materi Terkait".
  /// The screen owns this list and rebuilds when an item is removed
  /// via [onRemoveMaterialChip].
  List<Map<String, dynamic>> get materialChips;

  /// Removes the chip at [index] from [materialChips]. The screen
  /// state mutates the list and calls setState.
  void onRemoveMaterialChip(int index);

  /// Appends [mat] to [materialChips]. The screen state mutates the
  /// list and calls setState. Called after the teacher confirms the
  /// add-material picker.
  void onAddMaterialChip(Map<String, dynamic> mat);

  /// Subject_id (UUID — references `subject_schools.id`) the rec is
  /// scoped to. The materi picker uses this to fetch the curriculum's
  /// Bab + Sub-bab hierarchy. Returns null when the rec has no
  /// subject context — the picker falls through to a free-form mode
  /// in that case.
  String? get materialPickerSubjectId;

  Widget buildEditCard(Map<String, dynamic> rec, int index) {
    final recId = rec['id']?.toString() ?? UniqueKey().toString();
    final cobalt = ColorUtils.brandCobalt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecEditSectCard(
            icon: Icons.edit_rounded,
            iconBg: ColorUtils.violet700.withValues(alpha: 0.10),
            iconFg: ColorUtils.violet700,
            title: 'Judul',
            chip: 'Wajib',
            children: [_buildTitleField(recId)],
          ),
          const SizedBox(height: 10),
          RecEditSectCard(
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
          RecEditSectCard(
            icon: Icons.flag_rounded,
            iconBg: ColorUtils.warning600.withValues(alpha: 0.10),
            iconFg: ColorUtils.warning600,
            title: 'Prioritas',
            chip: 'Wajib',
            children: [_buildPriorityRow(recId)],
          ),
          const SizedBox(height: 10),
          RecEditSectCard(
            icon: Icons.menu_book_rounded,
            iconBg: cobalt.withValues(alpha: 0.10),
            iconFg: cobalt,
            title: 'Materi Terkait',
            chip: materialChips.isEmpty
                ? null
                : '${materialChips.length} dipilih',
            children: [_buildMaterialChipStrip()],
          ),
          const SizedBox(height: 10),
          RecEditSectCard(
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: ColorUtils.slate500.withValues(alpha: 0.10),
            iconFg: ColorUtils.slate600,
            title: 'Catatan Wali Kelas',
            chip: 'Opsional',
            children: [_buildNotesField()],
          ),
        ],
      ),
    );
  }

  /// Render the chips for selected materi (Mapel · Bab · Sub-bab),
  /// plus an outlined "+ Tambah Materi" affordance. Each chip carries
  /// an `×` button that calls back into [onRemoveMaterialChip].
  Widget _buildMaterialChipStrip() {
    final cobalt = ColorUtils.brandCobalt;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < materialChips.length; i++)
          RecEditMaterialChip(
            label: _materialLabel(materialChips[i]),
            color: _chipColorFor(materialChips[i]),
            onRemove: () => onRemoveMaterialChip(i),
          ),
        // "+ Tambah Materi" — opens the cobalt-themed picker sheet
        // below. On confirmation the picker pops with a Map carrying
        // type/title/description, which we hand off to
        // [onAddMaterialChip] to mutate the screen's materialChips
        // list.
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _openAddMaterialSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cobalt.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: cobalt.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 12, color: cobalt),
                const SizedBox(width: 4),
                Text(
                  'Tambah Materi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Open the add-material picker. Returns a `Map<String, dynamic>`
  /// shaped to match the materialChips contract:
  ///   {
  ///     type: 'chapter'|'sub_chapter',
  ///     title, description?,
  ///     chapter_id?, sub_chapter_id?, urutan?,
  ///   }
  /// When the rec carries a [materialPickerSubjectId] the picker loads
  /// the real curriculum (Bab + Sub-bab) for that subject; otherwise
  /// it falls back to a free-form one-liner so the wali can still
  /// pin a note.
  Future<void> _openAddMaterialSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) =>
          RecommendationAddMaterialSheet(subjectId: materialPickerSubjectId),
    );
    if (result != null &&
        result['title']?.toString().trim().isNotEmpty == true) {
      onAddMaterialChip(result);
    }
  }

  /// Pick a chip label that matches the mockup format —
  /// "Matematika" / "Bab 2" / "Sub: Op. Campuran" depending on what
  /// fields the materi map carries.
  String _materialLabel(Map<String, dynamic> mat) {
    final type = mat['type']?.toString() ?? '';
    final title = mat['title']?.toString() ?? mat['name']?.toString() ?? '-';
    if (type == 'subject') return title;
    if (type == 'chapter') return 'Bab ${mat['urutan'] ?? title}';
    if (type == 'sub_chapter') return 'Sub: $title';
    return title;
  }

  /// Subject chips → blue, bab → green, sub-bab → amber. Mirrors the
  /// mockup palette so each chip type stays visually distinct in a
  /// strip.
  Color _chipColorFor(Map<String, dynamic> mat) {
    final type = mat['type']?.toString() ?? '';
    if (type == 'chapter') return ColorUtils.success600;
    if (type == 'sub_chapter') return ColorUtils.warning600;
    return ColorUtils.brandCobalt;
  }

  /// Plain "Catatan Wali Kelas" textarea — wraps to 4 lines, no
  /// rich formatting, sits inside the slate-50 fill that matches the
  /// title field.
  Widget _buildNotesField() {
    final cobalt = ColorUtils.brandCobalt;
    return TextField(
      controller: notesController,
      minLines: 3,
      maxLines: 5,
      style: TextStyle(fontSize: 13, color: ColorUtils.slate800),
      decoration: InputDecoration(
        hintText: 'Tambahkan konteks pribadi atau langkah lanjutan...',
        hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
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
        contentPadding: const EdgeInsets.all(12),
        isDense: true,
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
          child: RecEditPriorityChip(
            label: 'Tinggi',
            value: 'high',
            current: current,
            color: ColorUtils.error600,
            onTap: () => setState(() => priorities[recId] = 'high'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RecEditPriorityChip(
            label: 'Sedang',
            value: 'medium',
            current: current,
            color: ColorUtils.warning600,
            onTap: () => setState(() => priorities[recId] = 'medium'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RecEditPriorityChip(
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
}
