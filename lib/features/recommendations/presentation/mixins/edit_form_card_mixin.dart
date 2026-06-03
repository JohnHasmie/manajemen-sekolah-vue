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
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

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
          _AddMaterialSheet(subjectId: materialPickerSubjectId),
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
//
// Long curriculum titles ("Kerajaan Hindu-Buddha & Pengaruhnya
// terhadap Masyarakat di Nusantara") used to spill out of the Wrap
// because the Row only honoured `MainAxisSize.min`. We now cap the
// chip at the parent's available width via `LayoutBuilder` and let
// the title `Text` ellipsize on a single line — same shape as the
// mockup, just truncated when the curriculum entry is verbose.

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
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 64;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
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
          ),
        );
      },
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

/// Cobalt-themed bottom sheet that pulls the curriculum (Bab + Sub-bab)
/// for the rec's `subject_id` and lets the wali kelas tag one of them.
///
/// Two-column layout. Left column: the chapter list for this subject
/// (selectable rows). Right column: the selected chapter's sub-chapter
/// list. The teacher can save a chapter alone (chip type=`chapter`)
/// or drill into a sub-chapter (`sub_chapter`). The picker stays
/// snapped to the curriculum to keep tags consistent across recs.
///
/// Falls back to a free-form one-liner when [subjectId] is null
/// (rec has no subject context, e.g. a generic homeroom note) so the
/// teacher always has *some* way to attach a chip.
///
/// Pops with a {type, title, description, chapter_id?, sub_chapter_id?,
/// urutan?} map on Save; null on Batal.
class _AddMaterialSheet extends StatefulWidget {
  final String? subjectId;

  const _AddMaterialSheet({this.subjectId});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  // ── Curriculum-backed state ──
  bool _loading = false;
  String? _loadError;
  List<Map<String, dynamic>> _chapters = const [];
  Map<String, dynamic>? _selectedChapter;
  Map<String, dynamic>? _selectedSubChapter;

  // ── Free-form fallback state (when subjectId is null) ──
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool get _isCurriculumMode =>
      widget.subjectId != null && widget.subjectId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isCurriculumMode) {
      _loadChapters();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: widget.subjectId,
      );
      if (!mounted) return;
      // Normalize to List<Map> + assign urutan ourselves so chips can
      // render "Bab 1", "Bab 2" predictably even when the backend
      // didn't ship the field.
      final chapters = <Map<String, dynamic>>[];
      var i = 0;
      for (final c in result) {
        if (c is Map) {
          final m = Map<String, dynamic>.from(c);
          m['urutan'] ??= ++i;
          chapters.add(m);
        }
      }
      setState(() {
        _chapters = chapters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Gagal memuat materi. Coba lagi.';
        _loading = false;
      });
    }
  }

  bool get _canSave {
    if (_isCurriculumMode) {
      return _selectedChapter != null;
    }
    return _titleCtrl.text.trim().isNotEmpty;
  }

  Map<String, dynamic>? _buildResult() {
    if (_isCurriculumMode) {
      final ch = _selectedChapter;
      if (ch == null) return null;

      // Sub-bab takes precedence when picked — chip color stays amber
      // and label ("Sub: …") makes the hierarchy obvious.
      if (_selectedSubChapter != null) {
        final sub = _selectedSubChapter!;
        return {
          'type': 'sub_chapter',
          'title': (sub['judul_sub_bab'] ?? sub['title'] ?? '-').toString(),
          'description': (sub['deskripsi_sub_bab'] ?? sub['description'] ?? '')
              .toString(),
          'chapter_id': ch['id']?.toString(),
          'sub_chapter_id': sub['id']?.toString(),
          'urutan': sub['urutan'],
          'subject_id': widget.subjectId,
        };
      }

      return {
        'type': 'chapter',
        'title': (ch['judul_bab'] ?? ch['title'] ?? '-').toString(),
        'description': (ch['deskripsi_bab'] ?? ch['description'] ?? '')
            .toString(),
        'chapter_id': ch['id']?.toString(),
        'urutan': ch['urutan'],
        'subject_id': widget.subjectId,
      };
    }

    // Free-form fallback (no subject context).
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) return null;
    return {
      'type': 'chapter',
      'title': t,
      'description': _descCtrl.text.trim(),
      '_local': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final maxH = MediaQuery.of(context).size.height * 0.86;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
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
                          _isCurriculumMode
                              ? 'Pilih Bab atau Sub-bab dari kurikulum mapel'
                              : 'Tambahkan referensi belajar bebas',
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
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _isCurriculumMode
                    ? _buildCurriculumBody()
                    : _buildFreeFormBody(cobalt),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(
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
                          ? () => Navigator.of(context).pop(_buildResult())
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Curriculum-mode body ──
  Widget _buildCurriculumBody() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(ColorUtils.brandCobalt),
            ),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: ColorUtils.error600,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _loadChapters,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ColorUtils.brandCobalt.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Coba lagi',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandCobalt,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_chapters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 28,
              color: ColorUtils.slate400,
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada Bab di kurikulum mapel ini.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Minta admin / guru mapel mendaftarkan materi terlebih dahulu.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final selected = _selectedChapter;
    final subs = (selected?['sub_chapters'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Pilih Bab'),
        const SizedBox(height: 6),
        Column(children: [for (final c in _chapters) _buildChapterRow(c)]),
        if (selected != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _label('Pilih Sub-bab', trailing: '· opsional')),
              if (_selectedSubChapter != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedSubChapter = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      'Batalkan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.brandCobalt,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (subs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Text(
                'Belum ada sub-bab. Bab akan disimpan sebagai materi.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate600,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final s in subs)
                  if (s is Map)
                    _buildSubChapterRow(Map<String, dynamic>.from(s)),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildChapterRow(Map<String, dynamic> ch) {
    final selected = _selectedChapter?['id'] == ch['id'];
    final color = ColorUtils.success600;
    final title = (ch['judul_bab'] ?? ch['title'] ?? '-').toString();
    final urutan = ch['urutan']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedChapter = ch;
          _selectedSubChapter = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : ColorUtils.slate200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  urutan,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : ColorUtils.slate800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubChapterRow(Map<String, dynamic> sub) {
    final selected = _selectedSubChapter?['id'] == sub['id'];
    final color = ColorUtils.warning600;
    final title = (sub['judul_sub_bab'] ?? sub['title'] ?? '-').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSubChapter = sub),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : ColorUtils.slate200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : ColorUtils.slate800,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ── Free-form fallback body ──
  Widget _buildFreeFormBody(Color cobalt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rekomendasi ini belum tertaut ke mapel — isi materi bebas.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
            hintText: 'mis. Latihan tambahan pecahan campuran',
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
            hintStyle: TextStyle(fontSize: 12.5, color: ColorUtils.slate400),
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
      ],
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
}
