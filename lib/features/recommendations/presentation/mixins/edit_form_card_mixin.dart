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

  Widget buildEditCard(Map<String, dynamic> rec, int index) {
    final recId = rec['id']?.toString() ?? UniqueKey().toString();
    final cobalt = ColorUtils.brandCobalt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 10),
          _SectCard(
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
          _SectCard(
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
          _MaterialChip(
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

  /// Open the add-material picker. Returns a Map<String, dynamic>
  /// shaped to match the materialChips contract:
  ///   { type: 'subject'|'chapter'|'sub_chapter', title, description? }
  /// Pre-fills nothing — the teacher types from scratch.
  Future<void> _openAddMaterialSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _AddMaterialSheet(),
    );
    if (result != null && result['title']?.toString().trim().isNotEmpty == true) {
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
      style: TextStyle(
        fontSize: 13,
        color: ColorUtils.slate800,
      ),
      decoration: InputDecoration(
        hintText: 'Tambahkan konteks pribadi atau langkah lanjutan...',
        hintStyle: TextStyle(
          fontSize: 13,
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

}

// ─── Material chip ─────────────────────────────────────────────────
// Tinted pill with subject/bab/sub-bab label and `×` remove button.
// Mirrors the SS2 mockup palette (subject blue / bab green /
// sub-bab amber). The owning widget hands in the chip color.

class _MaterialChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _MaterialChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: color),
            ),
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

// ─── Add-material picker sheet ──────────────────────────────────────

/// Cobalt-themed bottom sheet that lets the wali kelas attach a new
/// material chip to the rec they're editing. Three fields:
///   • Tipe — Mapel / Bab / Sub-bab (drives the chip color + label).
///   • Judul — free-form title text input.
///   • Keterangan — optional one-liner description.
/// Pops with a {type, title, description} map on Save; null on Batal.
class _AddMaterialSheet extends StatefulWidget {
  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  String _type = 'subject';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 4, bottom: 14),
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cobalt.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: cobalt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tambah Materi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Lampirkan referensi belajar untuk rekomendasi ini',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Tipe Materi'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _typeChip(
                    'subject',
                    'Mapel',
                    ColorUtils.brandCobalt,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _typeChip(
                    'chapter',
                    'Bab',
                    ColorUtils.success600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _typeChip(
                    'sub_chapter',
                    'Sub-bab',
                    ColorUtils.warning600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Judul'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate900,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'mis. Bab 2 Pecahan Campuran',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: ColorUtils.slate400,
                  fontWeight: FontWeight.w400,
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
            ),
            const SizedBox(height: 12),
            _label('Keterangan', trailing: '· opsional'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(fontSize: 12.5, color: ColorUtils.slate800),
              decoration: InputDecoration(
                hintText: 'Catatan untuk siswa atau orang tua…',
                hintStyle: TextStyle(
                  fontSize: 12.5,
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
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _canSave
                        ? () => Navigator.of(context).pop({
                              'type': _type,
                              'title': _titleCtrl.text.trim(),
                              'description': _descCtrl.text.trim(),
                              // Mark as locally added so the save mixin
                              // knows this is a fresh row, not a
                              // backend material id reference.
                              '_local': true,
                            })
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _canSave
                            ? cobalt
                            : cobalt.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _canSave
                            ? [
                                BoxShadow(
                                  color: cobalt.withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {String? trailing}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null)
            TextSpan(
              text: ' $trailing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
              ),
            ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label, Color color) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
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
