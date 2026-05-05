// Admin Pengumuman compose sheet — Mockup #10 applied.
//
// Replaces the legacy AnnouncementFormSheet for admin role: title
// input → AudienceMatrix toggle grid → live AudienceSummaryStrip
// (computes reach via /api/announcements/preview-reach as cells flip)
// → PinScheduleToggleStack (neutral "Kirim sekarang" + warning amber
// "📌 Sematkan") → footer.
//
// On save, posts {title, content, role_target, priority,
// audience_matrix, is_pinned, scheduled_at} to /api/announcement.
// Backend's existing CreateAnnouncementAction + the new
// audience_matrix migration handle persistence.
//
// Non-admin roles still use the legacy sheet — this one is admin-
// only by construction.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_announcement_components.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
import 'package:manajemensekolah/core/widgets/admin_form_sheet_header.dart';
import 'package:manajemensekolah/features/announcements/data/audience_preview_service.dart';

class AdminAnnouncementComposeSheet extends ConsumerStatefulWidget {
  /// Optional existing announcement to edit. Null = create mode.
  final Map<String, dynamic>? announcementData;
  final Color primaryColor;
  final VoidCallback? onSaved;

  const AdminAnnouncementComposeSheet({
    super.key,
    this.announcementData,
    required this.primaryColor,
    this.onSaved,
  });

  @override
  ConsumerState<AdminAnnouncementComposeSheet> createState() =>
      _AdminAnnouncementComposeSheetState();
}

class _AdminAnnouncementComposeSheetState
    extends ConsumerState<AdminAnnouncementComposeSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _api = ApiService();

  AudienceMatrixSelection _selection =
      const AudienceMatrixSelection({});
  AudiencePreview _preview = const AudiencePreview(
    total: 0,
    caption: 'Pilih minimal 1 audiens',
  );
  Timer? _debounce;
  bool _previewLoading = false;

  bool _sendNow = true;
  bool _pin = false;
  bool _isSaving = false;

  bool get _isEdit => widget.announcementData != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _titleController.text =
          (widget.announcementData!['title'] ?? '').toString();
      _contentController.text =
          (widget.announcementData!['content'] ?? '').toString();
      _pin = widget.announcementData!['is_pinned'] == true;
      // Future enhancement: rehydrate audience_matrix from edit data.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // The 4 columns rendered in the matrix. "Custom" opens a class
  // picker — TODO when class picker sheet exists.
  static const _columns = [
    AudienceColumn.all,
    AudienceColumn(label: '7', value: 7),
    AudienceColumn(label: '8', value: 8),
    AudienceColumn(label: '9', value: 9),
    AudienceColumn.custom,
  ];

  void _onCellToggle(AudienceRole role, Object value) {
    setState(() {
      _selection = _selection.toggle(role, value);
    });
    // Debounce reach preview so we don't fire on every tap.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      final preview = await ref
          .read(audiencePreviewServiceProvider)
          .fetch(_selection);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (_) {
      // Silent fall back — strip already shows "Pilih minimal 1 audiens"
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      SnackBarUtils.showError(
        context,
        'Judul dan isi pengumuman wajib diisi.',
      );
      return;
    }
    if (_selection.isEmpty) {
      SnackBarUtils.showError(
        context,
        'Pilih minimal 1 audiens.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Map the matrix selection back into legacy `role_target`
      // values so older readers keep working. If the matrix has any
      // wali_murid cell we mark the target as "wali"; else
      // teacher/student/all per role precedence.
      final apiPayload = _selection.toApiPayload();
      final roleTarget = _legacyRoleTarget(apiPayload);

      final body = <String, dynamic>{
        'title': title,
        'content': content,
        'role_target': roleTarget,
        'priority': _pin ? 'penting' : 'biasa',
        'audience_matrix': apiPayload,
        'is_pinned': _pin,
      };
      if (!_sendNow) {
        // For now, default scheduled_at to 1 hour from now if the
        // toggle is off. A future picker can replace this stub.
        body['scheduled_at'] = DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String();
      } else {
        body['sent_at'] =
            DateTime.now().toUtc().toIso8601String();
      }

      if (_isEdit) {
        await _api.put(
          '/announcement/${widget.announcementData!['id']}',
          body,
        );
      } else {
        await _api.post('/announcement', body);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved?.call();
      SnackBarUtils.showSuccess(
        context,
        _isEdit
            ? 'Pengumuman diperbarui'
            : 'Pengumuman dikirim ke ${_preview.total} orang',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _legacyRoleTarget(Map<String, List<Object>> matrix) {
    if (matrix['wali_murid']?.isNotEmpty ?? false) return 'wali';
    if (matrix['guru']?.isNotEmpty ?? false) return 'teacher';
    if (matrix['wali_kelas']?.isNotEmpty ?? false) return 'teacher';
    return 'all';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormSheetHeader(
              title: _isEdit ? 'Edit Pengumuman' : 'Tulis Pengumuman',
              kicker: _isEdit ? 'EDIT DATA' : 'TULIS BARU',
              isEditMode: _isEdit,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(text: 'JUDUL'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration('Misal: Persiapan PAS'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SectionLabel(text: 'ISI'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _contentController,
                      maxLines: 5,
                      decoration:
                          _inputDecoration('Tulis isi pengumuman…'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel(text: 'AUDIENS · matriks'),
                    const SizedBox(height: 6),
                    AudienceMatrix(
                      columns: _columns,
                      selection: _selection,
                      onToggle: _onCellToggle,
                      onCustomTap: () => SnackBarUtils.showInfo(
                        context,
                        'Pemilih kelas spesifik segera hadir.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AudienceSummaryStrip(
                      caption: _previewLoading
                          ? 'Menghitung audiens…'
                          : _preview.caption,
                      hasAudience: _preview.hasAudience,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel(text: 'PENJADWALAN'),
                    const SizedBox(height: 6),
                    AdminFormToggle(
                      title: 'Kirim sekarang',
                      subtitle: 'Notifikasi push langsung dikirim',
                      value: _sendNow,
                      onChanged: (v) => setState(() => _sendNow = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AdminFormToggle(
                      title: '📌 Sematkan',
                      subtitle: 'Tampil di atas list selama 7 hari',
                      tone: AdminToggleTone.warning,
                      value: _pin,
                      onChanged: (v) => setState(() => _pin = v),
                    ),
                  ],
                ),
              ),
            ),
            AdminFormFooter(
              primaryLabel: _isEdit
                  ? 'Simpan'
                  : (_preview.total > 0
                      ? 'Kirim ke ${_preview.total} orang'
                      : 'Kirim'),
              onPrimary: _preview.hasAudience ? _save : null,
              isSaving: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(
        fontSize: 12,
        color: ColorUtils.slate500,
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: ColorUtils.getRoleColor('admin'),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate500,
        letterSpacing: 0.5,
      ),
    );
  }
}
