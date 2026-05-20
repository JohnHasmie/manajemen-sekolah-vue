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
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';

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

  AudienceMatrixSelection _selection = const AudienceMatrixSelection({});
  AudiencePreview _preview = const AudiencePreview(
    total: 0,
    caption: 'Pilih minimal 1 audiens',
  );
  Timer? _debounce;
  bool _previewLoading = false;

  bool _sendNow = true;
  bool _pin = false;
  bool _isSaving = false;

  // ── Acara state ─────────────────────────────────────────────────
  // When [_hasEvent] is true, the form persists event_at + optional
  // event_end_at + event_has_time + event_location + reminder_offsets.
  bool _hasEvent = false;
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  bool _eventHasTime = true;
  final _eventLocationController = TextEditingController();
  // Default offsets match the mockup chips (1 hari, 1 jam, saat mulai).
  // Stored in minutes-before-event.
  static const _defaultOffsets = <int>[1440, 60, 0];
  Set<int> _reminderOffsets = {..._defaultOffsets};

  // ── Broadcast/Hari Tayang state ──────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _isEdit => widget.announcementData != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _titleController.text = (widget.announcementData!['title'] ?? '')
          .toString();
      _contentController.text = (widget.announcementData!['content'] ?? '')
          .toString();
      _pin = widget.announcementData!['is_pinned'] == true;
      _startDate = widget.announcementData!['start_date'] != null
          ? DateTime.tryParse(widget.announcementData!['start_date'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now();
      _endDate = widget.announcementData!['end_date'] != null
          ? DateTime.tryParse(widget.announcementData!['end_date'].toString())?.toLocal()
          : null;
      // Rehydrate audience_matrix from edit data.
      final existingMatrix = widget.announcementData!['audience_matrix'];
      if (existingMatrix is Map) {
        final cells = <MapEntry<AudienceRole, Object>>{};
        for (final entry in existingMatrix.entries) {
          final roleStr = entry.key.toString();
          AudienceRole? role;
          if (roleStr == AudienceRole.guru.apiKey) role = AudienceRole.guru;
          if (roleStr == AudienceRole.waliKelas.apiKey) role = AudienceRole.waliKelas;
          if (roleStr == AudienceRole.waliMurid.apiKey) role = AudienceRole.waliMurid;
          
          if (role != null && entry.value is List) {
            for (final val in (entry.value as List)) {
              cells.add(MapEntry(role, val));
            }
          }
        }
        _selection = AudienceMatrixSelection(cells);
        _refreshPreview();
      } else {
        // Fallback to legacy role_target if no matrix exists
        final rt = widget.announcementData!['role_target']?.toString() ?? 'all';
        final cells = <MapEntry<AudienceRole, Object>>{};
        if (rt == 'all' || rt == 'admin') {
          cells.add(const MapEntry(AudienceRole.guru, 'all'));
          cells.add(const MapEntry(AudienceRole.waliKelas, 'all'));
          cells.add(const MapEntry(AudienceRole.waliMurid, 'all'));
        } else if (rt == 'guru') {
          cells.add(const MapEntry(AudienceRole.guru, 'all'));
          cells.add(const MapEntry(AudienceRole.waliKelas, 'all'));
        } else if (rt == 'wali' || rt == 'siswa') {
          cells.add(const MapEntry(AudienceRole.waliMurid, 'all'));
        }
        _selection = AudienceMatrixSelection(cells);
        _refreshPreview();
      }
      // Rehydrate Acara payload when editing an announcement that
      // already carries one. AnnouncementEvent.fromJson returns null
      // for plain pengumuman — we keep _hasEvent = false in that case.
      final existing = AnnouncementEvent.fromJson(widget.announcementData!);
      if (existing != null) {
        _hasEvent = true;
        _eventDate = DateTime(
          existing.eventAt.year,
          existing.eventAt.month,
          existing.eventAt.day,
        );
        _eventHasTime = existing.eventHasTime;
        if (existing.eventHasTime) {
          _eventTime = TimeOfDay(
            hour: existing.eventAt.hour,
            minute: existing.eventAt.minute,
          );
        }
        if (existing.eventLocation != null) {
          _eventLocationController.text = existing.eventLocation!;
        }
        if (existing.reminderOffsetMinutes.isNotEmpty) {
          _reminderOffsets = existing.reminderOffsetMinutes.toSet();
        }
      }
    } else {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _eventLocationController.dispose();
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

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final initial = _eventDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickEventTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _eventTime = picked;
        _eventHasTime = true;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showModernDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      title: 'Pilih Tanggal Mulai Tayang',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showModernDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      title: 'Pilih Tanggal Selesai Tayang',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  /// Compose the event_at DateTime from the separate date + (optional)
  /// time inputs. Returns null when no date is set, or when time is
  /// hidden by the "Sepanjang hari" toggle (date is then anchored at
  /// 00:00 local).
  DateTime? get _composedEventAt {
    if (_eventDate == null) return null;
    if (_eventHasTime && _eventTime != null) {
      return DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        _eventTime!.hour,
        _eventTime!.minute,
      );
    }
    return DateTime(_eventDate!.year, _eventDate!.month, _eventDate!.day);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      SnackBarUtils.showError(context, 'Judul dan isi pengumuman wajib diisi.');
      return;
    }
    if (_selection.isEmpty) {
      SnackBarUtils.showError(context, 'Pilih minimal 1 audiens.');
      return;
    }
    if (_hasEvent && _eventDate == null) {
      SnackBarUtils.showError(context, 'Pilih tanggal acara dulu.');
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
        'start_date': _startDate?.toIso8601String(),
      };

      if (_endDate != null) {
        body['end_date'] = _endDate!.toIso8601String();
      } else if (_isEdit) {
        body['end_date'] = '__clear__';
      }

      // Acara payload — only included when the admin enabled the
      // Tambahkan Acara toggle. On edit, the sentinel "__clear__"
      // explicitly drops a previously-set event_at server-side.
      if (_hasEvent && _composedEventAt != null) {
        body['event_at'] = _composedEventAt!.toUtc().toIso8601String();
        body['event_has_time'] = _eventHasTime;
        if (_eventLocationController.text.trim().isNotEmpty) {
          body['event_location'] = _eventLocationController.text.trim();
        }
        body['reminder_offsets'] = _reminderOffsets.toList()..sort();
      } else if (_isEdit) {
        body['event_at'] = '__clear__';
      }

      if (!_sendNow) {
        // For now, default scheduled_at to 1 hour from now if the
        // toggle is off. A future picker can replace this stub.
        body['scheduled_at'] = DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String();
      } else {
        body['sent_at'] = DateTime.now().toUtc().toIso8601String();
      }

      if (_isEdit) {
        await _api.put('/announcement/${widget.announcementData!['id']}', body);
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                    const _SectionLabel(text: 'JUDUL'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration('Misal: Persiapan PAS'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _SectionLabel(text: 'ISI'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _contentController,
                      maxLines: 5,
                      decoration: _inputDecoration('Tulis isi pengumuman…'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel(text: 'AUDIENS · matriks'),
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
                    const _SectionLabel(text: 'HARI TAYANG'),
                    const SizedBox(height: 6),
                    _BroadcastDateTimeRow(
                      startDate: _startDate,
                      endDate: _endDate,
                      onPickStartDate: _pickStartDate,
                      onPickEndDate: _pickEndDate,
                      onClearEndDate: () => setState(() => _endDate = null),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel(text: 'ACARA · opsional'),
                    const SizedBox(height: 6),
                    AdminFormToggle(
                      title: 'Tambahkan Acara',
                      subtitle:
                          'Tanggal kejadian + reminder otomatis sebelum mulai',
                      value: _hasEvent,
                      onChanged: (v) => setState(() => _hasEvent = v),
                    ),
                    if (_hasEvent) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _EventDateTimeRow(
                        date: _eventDate,
                        time: _eventTime,
                        hasTime: _eventHasTime,
                        onPickDate: _pickEventDate,
                        onPickTime: _pickEventTime,
                        onClearTime: () => setState(() {
                          _eventTime = null;
                          _eventHasTime = false;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _eventLocationController,
                        decoration: _inputDecoration(
                          'Lokasi (opsional) · misal Aula Lt. 2',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _SectionLabel(text: 'KIRIM PERINGATAN'),
                      const SizedBox(height: 6),
                      _ReminderChipRow(
                        selected: _reminderOffsets,
                        onToggle: (offset) {
                          setState(() {
                            if (_reminderOffsets.contains(offset)) {
                              _reminderOffsets.remove(offset);
                            } else {
                              _reminderOffsets.add(offset);
                            }
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel(text: 'PENJADWALAN'),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(fontSize: 12, color: ColorUtils.slate500),
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

/// Two-cell row holding the date + jam pickers for the Acara block.
/// Tapping a cell opens its respective picker via the parent's
/// callbacks. The jam cell is visually muted when "Sepanjang hari"
/// is active (hasTime = false).
class _EventDateTimeRow extends StatelessWidget {
  const _EventDateTimeRow({
    required this.date,
    required this.time,
    required this.hasTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClearTime,
  });

  final DateTime? date;
  final TimeOfDay? time;
  final bool hasTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onClearTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 14,
          child: _PickerCell(
            label: 'Tanggal',
            value: date == null ? 'Pilih tanggal' : _fmtDate(date!),
            icon: Icons.calendar_today_outlined,
            onTap: onPickDate,
            placeholder: date == null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 10,
          child: _PickerCell(
            label: hasTime ? 'Jam' : 'Jam',
            value: hasTime
                ? (time == null ? 'Pilih jam' : _fmtTime(time!))
                : 'Sepanjang hari',
            icon: Icons.access_time_rounded,
            onTap: hasTime ? onPickTime : onPickTime,
            placeholder: hasTime && time == null,
            trailing: hasTime && time != null
                ? GestureDetector(
                    onTap: onClearTime,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: ColorUtils.slate400,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder = false,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool placeholder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 13,
                color: ColorUtils.getRoleColor('admin'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: placeholder
                          ? ColorUtils.slate400
                          : ColorUtils.slate900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Reminder-offset chip row. Each chip toggles inclusion of a fixed
/// offset (in minutes-before-event). The set persists into the
/// reminder_offsets JSONB column on save.
class _ReminderChipRow extends StatelessWidget {
  const _ReminderChipRow({required this.selected, required this.onToggle});

  final Set<int> selected;
  final void Function(int offsetMinutes) onToggle;

  static const _options = <_ReminderOption>[
    _ReminderOption(label: '1 hari sblm', value: 1440),
    _ReminderOption(label: '1 jam sblm', value: 60),
    _ReminderOption(label: '30 mnt sblm', value: 30),
    _ReminderOption(label: 'Saat mulai', value: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _options.map((opt) {
        final isOn = selected.contains(opt.value);
        final bg = isOn ? const Color(0xFFFEF3C7) : ColorUtils.slate50;
        final fg = isOn ? const Color(0xFFB45309) : ColorUtils.slate600;
        final border = isOn ? const Color(0xFFFDE68A) : ColorUtils.slate300;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onToggle(opt.value),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: border,
                  style: isOn ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOn
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    size: 12,
                    color: fg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReminderOption {
  const _ReminderOption({required this.label, required this.value});
  final String label;
  final int value;
}

class _BroadcastDateTimeRow extends StatelessWidget {
  const _BroadcastDateTimeRow({
    required this.startDate,
    required this.endDate,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onClearEndDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearEndDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PickerCell(
            label: 'Mulai Tayang',
            value: startDate == null ? 'Pilih tanggal' : _fmtDate(startDate!),
            icon: Icons.play_arrow_rounded,
            onTap: onPickStartDate,
            placeholder: startDate == null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _PickerCell(
            label: 'Selesai Tayang',
            value: endDate == null ? 'Selamanya (Indefinite)' : _fmtDate(endDate!),
            icon: Icons.stop_rounded,
            onTap: onPickEndDate,
            placeholder: endDate == null,
            trailing: endDate != null
                ? GestureDetector(
                    onTap: onClearEndDate,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: ColorUtils.slate400,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
