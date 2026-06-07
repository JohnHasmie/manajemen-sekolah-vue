// Tagih reminder confirmation sheet — Mockup #13.
//
// Opens when the admin taps the navy "Tagih" button on an unpaid /
// overdue [InvoiceRow]. The sheet summarises the bill (title, student,
// amount, overdue days), lets the admin pick the reminder channel
// (WhatsApp / Email — radio chips), and on Konfirmasi increments the
// bill's `reminder_count` locally so the next render shows the
// updated "Reminder ke-N" pill on the row.
//
// The actual reminder dispatch (push notification, email, SMS) is a
// backend concern that doesn't exist yet — this sheet returns a
// `TagihReminderResult` to the caller so the screen-level state can
// optimistically bump the counter and show a success snackbar.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Channel chosen by the admin in the reminder sheet.
enum TagihReminderChannel { whatsapp, email }

/// Returned to the caller when the admin confirms the reminder.
class TagihReminderResult {
  final TagihReminderChannel channel;
  const TagihReminderResult({required this.channel});
}

/// Opens the reminder confirmation sheet for [bill]. Resolves to a
/// non-null [TagihReminderResult] when the admin confirms, or `null`
/// if dismissed.
Future<TagihReminderResult?> showTagihReminderSheet(
  BuildContext context, {
  required Map<String, dynamic> bill,
}) {
  return AppBottomSheet.show<TagihReminderResult>(
    context: context,
    title: kFinSendBillReminder.tr,
    subtitle: kFinSelectChannelConfirm.tr,
    icon: Icons.campaign_rounded,
    primaryColor: ColorUtils.getRoleColor('admin'),
    content: _TagihReminderContent(bill: bill),
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
  );
}

class _TagihReminderContent extends StatefulWidget {
  final Map<String, dynamic> bill;
  const _TagihReminderContent({required this.bill});

  @override
  State<_TagihReminderContent> createState() => _TagihReminderContentState();
}

class _TagihReminderContentState extends State<_TagihReminderContent> {
  TagihReminderChannel _channel = TagihReminderChannel.whatsapp;
  bool _sending = false;

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bill = widget.bill;

    final studentMap = bill['student'] is Map
        ? Map<String, dynamic>.from(bill['student'] as Map)
        : null;
    final classesList = studentMap?['classes'] is List
        ? (studentMap!['classes'] as List)
        : const [];
    String? classLabel;
    if (classesList.isNotEmpty && classesList.first is Map) {
      classLabel = (classesList.first['name'] ?? classesList.first['nama'])
          ?.toString();
    }
    final studentName =
        (studentMap?['name'] ??
                bill['student_name'] ??
                bill['nama_siswa'] ??
                'Siswa')
            .toString();
    final typeName =
        (bill['name'] ??
                bill['title'] ??
                (bill['payment_type'] is Map
                    ? bill['payment_type']['name']
                    : null) ??
                (bill['paymentType'] is Map
                    ? bill['paymentType']['name']
                    : null) ??
                'Tagihan')
            .toString();
    final amount = double.tryParse((bill['amount'] ?? 0).toString()) ?? 0;
    final dueRaw =
        bill['due_date'] ?? bill['jatuh_tempo'] ?? bill['tanggal_jatuh_tempo'];
    final due = dueRaw == null ? null : DateTime.tryParse(dueRaw.toString());
    final now = DateTime.now();
    final overdueDays = due != null && due.isBefore(now)
        ? now.difference(due).inDays
        : 0;
    final reminderCount = (bill['reminder_count'] as num?)?.toInt() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Bill summary card ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                classLabel == null || classLabel.isEmpty
                    ? typeName
                    : '$typeName · $classLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                studentName,
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _idr.format(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: overdueDays > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F172A),
                ),
              ),
              if (overdueDays > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '⚠ Lewat $overdueDays hari · '
                  'sudah dikirim $reminderCount pengingat',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        // ── Channel chooser ──────────────────────────────────────
        Text(
          'SALURAN PENGINGAT',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChannelTile(
                icon: Icons.chat_bubble_rounded,
                label: kFinWhatsApp.tr,
                hint: 'Pesan ke wali',
                active: _channel == TagihReminderChannel.whatsapp,
                accent: navy,
                onTap: () =>
                    setState(() => _channel = TagihReminderChannel.whatsapp),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChannelTile(
                icon: Icons.alternate_email_rounded,
                label: kFinEmail.tr,
                hint: 'Surat resmi',
                active: _channel == TagihReminderChannel.email,
                accent: navy,
                onTap: () =>
                    setState(() => _channel = TagihReminderChannel.email),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengingat akan tercatat sebagai '
                  '"Reminder ke-${reminderCount + 1}" pada baris tagihan.',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: navy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BottomSheetFooter(
          primaryLabel: _sending ? 'Mengirim…' : 'Konfirmasi',
          primaryColor: navy,
          primaryEnabled: !_sending,
          onPrimary: _confirm,
          onSecondary: _sending ? () {} : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _confirm() {
    setState(() => _sending = true);
    // No real backend call yet — close immediately with the chosen
    // channel. The screen-level handler increments the local
    // reminder_count and shows a success snackbar.
    Navigator.of(context).pop(TagihReminderResult(channel: _channel));
  }
}

class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accent : ColorUtils.slate200,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? accent : ColorUtils.slate500,
                ),
                const SizedBox(width: 6),
                if (active)
                  Icon(Icons.check_circle_rounded, size: 14, color: accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? accent : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
