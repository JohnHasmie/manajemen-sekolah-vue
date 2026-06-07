// Per-section material editor — focused draggable sheet.
//
// Mirrors `lesson_plan_section_editor_sheet.dart`'s shape (cobalt
// gradient header + TextField body + Batal/Simpan footer) but lighter:
// material_content keys (`ringkasan`, `cara_mengajar`, …) are plain
// strings or simple lists, so a multi-line TextField is enough — no
// Quill rich text needed.
//
// Returns a [MaterialSectionEditResult] on save with the new value;
// returns null when the user dismisses.
//
// Persistence: the AI service does not (yet) expose a PATCH endpoint
// for `generated_materials.material_content`, so the parent screen
// applies the edit to its local `_aiGeneratedData` map and rewrites
// the sub-chapter cache. A backend PATCH should hook here later
// without changing the sheet contract.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';

/// Result returned to the parent screen after the sheet closes.
///
/// `newValue` carries the new plain-text value the user typed. For
/// list-shaped sections (e.g. `poin_utama`) the parent should split
/// `newValue` on newlines back into a `List<String>` before merging.
class MaterialSectionEditResult {
  final String fieldKey;
  final String newValue;
  const MaterialSectionEditResult({
    required this.fieldKey,
    required this.newValue,
  });
}

/// Open the material section editor sheet.
///
/// `currentValue` seeds the TextField — for list-shaped sections, the
/// caller should join the items with `\n` so each item lives on its
/// own line. Round-trip is the parent's job.
Future<MaterialSectionEditResult?> showMaterialSectionEditorSheet({
  required BuildContext context,
  required String fieldKey,
  required String fieldLabel,
  required String currentValue,
  String? hint,
}) {
  return AppDraggableSheet.show<MaterialSectionEditResult>(
    context: context,
    initialSize: 0.92,
    minSize: 0.6,
    maxSize: 0.96,
    builder: (sheetCtx, scrollController) => _MaterialSectionEditorSheet(
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      currentValue: currentValue,
      hint: hint,
    ),
  );
}

class _MaterialSectionEditorSheet extends StatefulWidget {
  const _MaterialSectionEditorSheet({
    required this.fieldKey,
    required this.fieldLabel,
    required this.currentValue,
    required this.hint,
  });

  final String fieldKey;
  final String fieldLabel;
  final String currentValue;
  final String? hint;

  @override
  State<_MaterialSectionEditorSheet> createState() =>
      _MaterialSectionEditorSheetState();
}

class _MaterialSectionEditorSheetState
    extends State<_MaterialSectionEditorSheet> {
  late final TextEditingController _controller;
  late final String _initial;
  bool _isDirty = false;

  Color get _accent => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _initial = widget.currentValue;
    _controller = TextEditingController(text: _initial);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final dirty = _controller.text != _initial;
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  void _save() {
    if (!_isDirty) return;
    AppNavigator.pop(
      context,
      MaterialSectionEditResult(
        fieldKey: widget.fieldKey,
        newValue: _controller.text,
      ),
    );
  }

  Future<void> _attemptClose() async {
    if (!_isDirty) {
      AppNavigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kMatCancelChanges.tr),
        content: Text(
          kMatChangesNotSaved.tr.replaceAll('{label}', widget.fieldLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(kMatKeepEditing.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ColorUtils.error600),
            child: Text(kMatDiscard.tr),
          ),
        ],
      ),
    );
    if (discard == true && mounted) AppNavigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            _buildBrandHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: ColorUtils.slate800,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint ?? kMatWriteContent.tr.replaceAll('{label}', widget.fieldLabel),
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate400,
                    ),
                    filled: true,
                    fillColor: ColorUtils.slate50,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _accent, width: 1.4),
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent,
            Color.lerp(_accent, Colors.lightBlueAccent, 0.35) ?? _accent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kMatEditSection.tr,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edit ${widget.fieldLabel}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _attemptClose,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canSave = _isDirty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _attemptClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorUtils.slate700,
                  side: BorderSide(color: ColorUtils.slate200),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  kCancel.tr,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: canSave ? _save : null,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  kSave.tr,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ColorUtils.slate200,
                  disabledForegroundColor: ColorUtils.slate400,
                  minimumSize: const Size.fromHeight(44),
                  elevation: canSave ? 6 : 0,
                  shadowColor: _accent.withValues(alpha: 0.28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
