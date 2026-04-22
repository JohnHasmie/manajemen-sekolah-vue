import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Result returned by [showAddChapterSheet].
///
/// - [name] is the column label (e.g. "Bab 2 - Pecahan", "UH 1").
/// - [assessment] describes which existing assessment to pull per-student
///   scores from. `null` means manual input — cells stay blank and the
///   teacher fills them row-by-row.
class AddChapterResult {
  final String name;

  /// Identifier of the source assessment to pull scores from, or `null` for
  /// manual input. Shape:
  /// ```
  /// { 'title': 'Tugas 1', 'type': 'tugas', 'date': '2025-09-14' }
  /// ```
  final Map<String, dynamic>? assessment;

  const AddChapterResult({
    required this.name,
    required this.assessment,
  });
}

/// Modal bottom sheet for adding a new grade column.
///
/// Two-step flow:
///   1. **Materi / Bab** — pick from the teacher's existing lesson-plan
///      titles for this subject (pre-defined "bab"), or type a custom name.
///   2. **Cara mengisi nilai** — pick one of the teacher's existing
///      assessments (Tugas, UH, etc.) to pull per-student scores from, or
///      choose "Input Manual" to leave the column blank.
///
/// Resolves with [AddChapterResult] on "Tambah", or `null` on dismiss.
Future<AddChapterResult?> showAddChapterSheet({
  required BuildContext context,
  required Color primaryColor,
  required int nextChapterIndex,
  required List<String> availableMaterials,
  required List<Map<String, dynamic>> availableAssessments,
}) {
  return showModalBottomSheet<AddChapterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      return _AddChapterSheet(
        primaryColor: primaryColor,
        nextChapterIndex: nextChapterIndex,
        availableMaterials: availableMaterials,
        availableAssessments: availableAssessments,
      );
    },
  );
}

class _AddChapterSheet extends StatefulWidget {
  final Color primaryColor;
  final int nextChapterIndex;
  final List<String> availableMaterials;
  final List<Map<String, dynamic>> availableAssessments;

  const _AddChapterSheet({
    required this.primaryColor,
    required this.nextChapterIndex,
    required this.availableMaterials,
    required this.availableAssessments,
  });

  @override
  State<_AddChapterSheet> createState() => _AddChapterSheetState();
}

class _AddChapterSheetState extends State<_AddChapterSheet> {
  // ── Step 1 state ────────────────────────────────────────
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;
  String? _selectedMaterial;
  bool _customMode = false;

  // ── Step 2 state ────────────────────────────────────────
  /// Selected assessment to pull scores from. `null` means manual.
  Map<String, dynamic>? _selectedAssessment;
  bool _manualSelected = true;

  int _step = 0; // 0 = materi, 1 = cara mengisi

  @override
  void initState() {
    super.initState();
    final defaultName = 'Bab ${widget.nextChapterIndex + 1}';
    _nameController = TextEditingController(text: defaultName);
    _nameFocus = FocusNode();

    // Auto-select the first material if available; otherwise drop into
    // custom-input mode so the text field is front-and-center.
    if (widget.availableMaterials.isNotEmpty) {
      _selectedMaterial = widget.availableMaterials.first;
      _nameController.text = _selectedMaterial!;
    } else {
      _customMode = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _pickMaterial(String name) {
    setState(() {
      _selectedMaterial = name;
      _customMode = false;
      _nameController.text = name;
      _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: name.length),
      );
    });
  }

  void _enableCustom() {
    setState(() {
      _customMode = true;
      _selectedMaterial = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  void _pickAssessment(Map<String, dynamic>? a) {
    setState(() {
      _selectedAssessment = a;
      _manualSelected = a == null;
    });
  }

  void _goNext() {
    if (_nameController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    setState(() => _step = 0);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      AddChapterResult(
        name: name,
        assessment: _manualSelected ? null : _selectedAssessment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 0
                              ? 'Tambah Materi / Bab'
                              : 'Cara Mengisi Nilai',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _step == 0
                              ? 'Langkah 1 dari 2 — pilih materi pembelajaran'
                              : 'Langkah 2 dari 2 — pilih sumber nilai',
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 18,
                    child: Icon(
                      Icons.close_rounded,
                      color: ColorUtils.slate500,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildProgress(),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _step == 0 ? _buildStepMateri() : _buildStepFill(),
                ),
              ),
              const SizedBox(height: 18),
              _buildNavRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: widget.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: _step == 1 ? widget.primaryColor : ColorUtils.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: pick materi or custom ───────────────────────

  Widget _buildStepMateri() {
    final materials = widget.availableMaterials;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          materials.isEmpty
              ? 'Belum ada materi pembelajaran terdaftar. Ketik nama kolom '
                  'secara manual.'
              : 'Pilih dari materi pembelajaran yang sudah Anda buat, atau '
                  'ketik nama sendiri.',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
        const SizedBox(height: 12),
        if (materials.isNotEmpty) ...[
          for (final m in materials) _buildMaterialTile(m),
          const SizedBox(height: 8),
          _buildCustomToggleTile(),
        ],
        if (_customMode || materials.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Nama kolom',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textInputAction: TextInputAction.next,
            onChanged: (v) {
              if (_selectedMaterial != null && v != _selectedMaterial) {
                setState(() => _selectedMaterial = null);
              }
            },
            onSubmitted: (_) => _goNext(),
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate800,
            ),
            decoration: _inputDecoration(hint: 'mis. Bab 3 - Pecahan'),
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialTile(String name) {
    final selected = !_customMode && _selectedMaterial == name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? widget.primaryColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _pickMaterial(name),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    selected ? widget.primaryColor : ColorUtils.slate200,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? widget.primaryColor.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? widget.primaryColor.withValues(alpha: 0.35)
                          : ColorUtils.slate200,
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 16,
                    color: selected
                        ? widget.primaryColor
                        : ColorUtils.slate600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? widget.primaryColor
                          : ColorUtils.slate800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: widget.primaryColor,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomToggleTile() {
    final selected = _customMode;
    return Material(
      color: selected
          ? widget.primaryColor.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _enableCustom,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? widget.primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? widget.primaryColor.withValues(alpha: 0.15)
                      : ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? widget.primaryColor.withValues(alpha: 0.35)
                        : ColorUtils.slate200,
                  ),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color:
                      selected ? widget.primaryColor : ColorUtils.slate600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama Custom',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? widget.primaryColor
                            : ColorUtils.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ketik nama kolom sendiri',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: widget.primaryColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 2: pick assessment source or manual ────────────

  Widget _buildStepFill() {
    final grouped = _groupAssessments(widget.availableAssessments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih sumber nilai untuk "${_nameController.text.trim()}".',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
        const SizedBox(height: 12),
        _buildManualCard(),
        if (grouped.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'AMBIL DARI NILAI YANG SUDAH ADA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in grouped.entries) ...[
            _buildTypeHeader(entry.key),
            const SizedBox(height: 6),
            for (final a in entry.value) _buildAssessmentTile(a),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildManualCard() {
    final selected = _manualSelected;
    return Material(
      color: selected
          ? widget.primaryColor.withValues(alpha: 0.08)
          : ColorUtils.slate50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _pickAssessment(null),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? widget.primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? widget.primaryColor.withValues(alpha: 0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? widget.primaryColor.withValues(alpha: 0.35)
                        : ColorUtils.slate200,
                  ),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color:
                      selected ? widget.primaryColor : ColorUtils.slate600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Input Manual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? widget.primaryColor
                            : ColorUtils.slate800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Biarkan kosong, Anda isi nilai per siswa di tabel.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: widget.primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeHeader(String type) {
    return Text(
      _typeLabel(type),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildAssessmentTile(Map<String, dynamic> a) {
    final selected = !_manualSelected &&
        _selectedAssessment != null &&
        _selectedAssessment!['title'] == a['title'] &&
        _selectedAssessment!['date'] == a['date'] &&
        _selectedAssessment!['type'] == a['type'];
    final title = (a['title'] ?? '-').toString();
    final date = (a['date'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? widget.primaryColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _pickAssessment(a),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? widget.primaryColor : ColorUtils.slate200,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? widget.primaryColor
                              : ColorUtils.slate800,
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: widget.primaryColor,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Nav row ──────────────────────────────────────────────

  Widget _buildNavRow() {
    if (_step == 0) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _nameController.text.trim().isEmpty ? null : _goNext,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text(
            'Lanjut',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate300,
            elevation: 2,
            shadowColor: widget.primaryColor.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Kembali',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorUtils.slate700,
              side: BorderSide(color: ColorUtils.slate300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Tambah Kolom',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: widget.primaryColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: ColorUtils.slate400,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: ColorUtils.slate50,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
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
        borderSide: BorderSide(color: widget.primaryColor, width: 1.4),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  /// Groups assessments by their `type` (tugas, uh, uts, uas, …) and
  /// returns a map in a stable, teacher-friendly order.
  Map<String, List<Map<String, dynamic>>> _groupAssessments(
    List<Map<String, dynamic>> list,
  ) {
    final order = ['tugas', 'uh', 'quiz', 'praktek', 'proyek', 'uts', 'uas'];
    final map = <String, List<Map<String, dynamic>>>{};
    for (final a in list) {
      final type = (a['type'] ?? 'lainnya').toString().toLowerCase();
      map.putIfAbsent(type, () => []).add(a);
    }
    // Sort by the preferred order first, then any unknown types alphabetically.
    final sortedKeys = [
      ...order.where(map.containsKey),
      ...map.keys.where((k) => !order.contains(k))..toList(),
    ];
    return {for (final k in sortedKeys) k: map[k]!};
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'tugas':
        return 'Tugas';
      case 'uh':
        return 'Ulangan Harian';
      case 'quiz':
        return 'Quiz';
      case 'praktek':
        return 'Praktek';
      case 'proyek':
        return 'Proyek';
      case 'uts':
      case 'pts':
        return 'UTS / PTS';
      case 'uas':
      case 'pas':
        return 'UAS / PAS';
      default:
        return type.toUpperCase();
    }
  }
}
