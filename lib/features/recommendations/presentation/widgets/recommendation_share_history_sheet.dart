// Riwayat Pengiriman sheet — Frame J of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Cobalt-themed AppDraggableSheet showing every parent recipient for
// a given recommendation. Each recipient gets:
//   • avatar tinted by lifecycle stage (green = read/replied,
//     cobalt = delivered, slate = sent)
//   • 4-dot vertical timeline (sent → delivered → read → replied)
//   • inline reply text when present
//   • Ingatkan Ulang / Tarik Pesan / Edit & Kirim Ulang per recipient
// Footer: Tutup + cobalt Bagikan Lagi (re-open the share sheet).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';

/// Returns true when the sheet was closed after one or more share
/// mutations (revoke / resend) so the caller can refresh the rec.
Future<bool?> showRecommendationShareHistorySheet({
  required BuildContext context,
  required Map<String, dynamic> recommendation,
  VoidCallback? onShareAgain,
}) {
  return AppDraggableSheet.show<bool>(
    context: context,
    initialSize: 0.86,
    minSize: 0.5,
    maxSize: 0.96,
    builder: (sheetContext, scrollController) =>
        _RecommendationShareHistorySheet(
          recommendation: recommendation,
          scrollController: scrollController,
          onShareAgain: onShareAgain,
        ),
  );
}

class _RecommendationShareHistorySheet extends StatefulWidget {
  final Map<String, dynamic> recommendation;
  final ScrollController scrollController;
  final VoidCallback? onShareAgain;

  const _RecommendationShareHistorySheet({
    required this.recommendation,
    required this.scrollController,
    this.onShareAgain,
  });

  @override
  State<_RecommendationShareHistorySheet> createState() =>
      _RecommendationShareHistorySheetState();
}

class _RecommendationShareHistorySheetState
    extends State<_RecommendationShareHistorySheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await getIt<ApiRecommendationService>().getShareStatus(
        widget.recommendation['id'].toString(),
      );
      if (mounted) {
        setState(() {
          _data = res['data'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal memuat riwayat: $e');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          _buildGrabber(),
          _buildHeader(cobalt),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(cobalt),
          ),
          BottomSheetFooter(
            primaryLabel: 'Bagikan Lagi',
            primaryColor: cobalt,
            onPrimary: () {
              Navigator.of(context).pop(_dirty);
              widget.onShareAgain?.call();
            },
            onSecondary: () => Navigator.of(context).pop(_dirty),
            secondaryLabel: 'Tutup',
          ),
        ],
      ),
    );
  }

  Widget _buildGrabber() => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: ColorUtils.slate200,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );

  Widget _buildHeader(Color cobalt) {
    final title = widget.recommendation['title']?.toString() ?? 'Rekomendasi';
    final count = (_data?['recipient_count'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cobalt.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.share_rounded, size: 16, color: cobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Riwayat Pengiriman',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$title · $count wali',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: ColorUtils.slate500,
            ),
            onPressed: () => Navigator.of(context).pop(_dirty),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color cobalt) {
    final read = (_data?['read_count'] as num?)?.toInt() ?? 0;
    final total = (_data?['recipient_count'] as num?)?.toInt() ?? 0;
    final replied = (_data?['replied_count'] as num?)?.toInt() ?? 0;
    final recipients = (_data?['recipients'] as List?) ?? const [];

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: '$read',
                label: 'DIBACA',
                color: ColorUtils.success600,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatCell(
                value: '$total',
                label: 'TERKIRIM',
                color: cobalt,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatCell(
                value: '$replied',
                label: 'DIBALAS',
                color: ColorUtils.warning600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (recipients.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Text(
              'Belum ada wali yang menerima rekomendasi ini.',
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          for (final r in recipients)
            _RecipientTimeline(
              data: r as Map<String, dynamic>,
              cobalt: cobalt,
              onRemind: () => _handleRemind(r),
              onRevoke: () => _handleRevoke(r),
              onEditResend: () => _handleEditResend(r),
            ),
      ],
    );
  }

  Future<void> _handleRemind(Map<String, dynamic> recipient) async {
    try {
      await getIt<ApiRecommendationService>().remindRecipient(
        recommendationId: widget.recommendation['id'].toString(),
        recipientId: recipient['id'].toString(),
      );
      _dirty = true;
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Pengingat terkirim ulang.');
        await _load();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Gagal: $e');
    }
  }

  Future<void> _handleRevoke(Map<String, dynamic> recipient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Tarik Pesan?',
        content:
            'Pesan akan disembunyikan dari ${recipient['parent_name'] ?? 'wali'} '
            'dan tidak bisa dibaca lagi. Anda tetap bisa Bagikan Ulang nanti.',
        confirmText: 'Tarik Pesan',
      ),
    );
    if (confirmed != true) return;

    try {
      await getIt<ApiRecommendationService>().revokeRecipient(
        recommendationId: widget.recommendation['id'].toString(),
        recipientId: recipient['id'].toString(),
      );
      _dirty = true;
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Pesan ditarik.');
        await _load();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Gagal: $e');
    }
  }

  Future<void> _handleEditResend(Map<String, dynamic> recipient) async {
    final messageCtrl = TextEditingController(
      text: (_data?['shared_message'] as String?) ?? '',
    );
    final cobalt = ColorUtils.brandCobalt;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Edit Pesan untuk ${recipient['parent_name']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
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
                ),
              ),
              const SizedBox(height: 14),
              BottomSheetFooter(
                primaryLabel: 'Kirim Ulang',
                primaryColor: cobalt,
                onPrimary: () => Navigator.of(ctx).pop(messageCtrl.text.trim()),
                onSecondary: () => Navigator.of(ctx).pop(null),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;

    try {
      await getIt<ApiRecommendationService>().editAndResendRecipient(
        recommendationId: widget.recommendation['id'].toString(),
        recipientId: recipient['id'].toString(),
        message: result,
      );
      _dirty = true;
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Pesan diperbarui & dikirim ulang.');
        await _load();
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, 'Gagal: $e');
    }
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientTimeline extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cobalt;
  final VoidCallback onRemind;
  final VoidCallback onRevoke;
  final VoidCallback onEditResend;

  const _RecipientTimeline({
    required this.data,
    required this.cobalt,
    required this.onRemind,
    required this.onRevoke,
    required this.onEditResend,
  });

  String get _initials {
    final name = (data['parent_name'] ?? 'W').toString().trim();
    if (name.isEmpty) return 'W';
    final bits = name.split(RegExp(r'\s+'));
    if (bits.length == 1) return bits.first.substring(0, 1).toUpperCase();
    return (bits.first.substring(0, 1) + bits.last.substring(0, 1))
        .toUpperCase();
  }

  String _fmtTime(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
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
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} · $hh:$mm';
    } catch (_) {
      return ts.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = data['lifecycle_stage']?.toString() ?? 'sent';
    final readAt = data['read_at'];
    final repliedAt = data['replied_at'];
    final revokedAt = data['revoked_at'];
    final replyText = data['reply_text']?.toString() ?? '';

    final (avBg, avFg, statusLabel, statusColor) = _resolveStatus(
      stage,
      cobalt,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: avBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: avFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data['parent_name']?.toString() ?? 'Wali',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _channelLine(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimeline(readAt, repliedAt, revokedAt, replyText),
          const SizedBox(height: 10),
          if (revokedAt == null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniAction(
                  icon: Icons.notifications_active_rounded,
                  label: 'Ingatkan',
                  color: cobalt,
                  onTap: onRemind,
                ),
                _MiniAction(
                  icon: Icons.edit_rounded,
                  label: 'Edit & Kirim Ulang',
                  color: cobalt,
                  onTap: onEditResend,
                ),
                _MiniAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Tarik',
                  color: ColorUtils.error600,
                  onTap: onRevoke,
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 12,
                    color: ColorUtils.error600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pesan ditarik · ${_fmtTime(revokedAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.error600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _channelLine() {
    final relation = (data['parent_relation'] ?? 'wali').toString();
    final wa = data['channel_whatsapp'] == true;
    return '${relation[0].toUpperCase()}${relation.substring(1)}'
        ' · push${wa ? ' · WhatsApp' : ''}';
  }

  (Color, Color, String, Color) _resolveStatus(String stage, Color cobalt) {
    switch (stage) {
      case 'replied':
        return (
          ColorUtils.warning600.withValues(alpha: 0.10),
          ColorUtils.warning600,
          'SUDAH DIBALAS',
          ColorUtils.warning600,
        );
      case 'read':
        return (
          ColorUtils.success600.withValues(alpha: 0.10),
          ColorUtils.success600,
          'SUDAH DIBACA',
          ColorUtils.success600,
        );
      case 'delivered':
        return (cobalt.withValues(alpha: 0.10), cobalt, 'TERKIRIM', cobalt);
      case 'revoked':
        return (
          ColorUtils.error600.withValues(alpha: 0.10),
          ColorUtils.error600,
          'DITARIK',
          ColorUtils.error600,
        );
      default:
        return (
          ColorUtils.warning600.withValues(alpha: 0.10),
          ColorUtils.warning600,
          'BELUM DIBACA',
          ColorUtils.warning600,
        );
    }
  }

  Widget _buildTimeline(
    dynamic readAt,
    dynamic repliedAt,
    dynamic revokedAt,
    String replyText,
  ) {
    final sentAt = data['sent_at'];
    final deliveredAt = data['delivered_at'] ?? sentAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _Dot(filled: true, color: ColorUtils.success600),
            _Bar(),
            _Dot(filled: deliveredAt != null, color: ColorUtils.success600),
            _Bar(),
            _Dot(filled: readAt != null, color: ColorUtils.success600),
            if (repliedAt != null) ...[
              _Bar(),
              _Dot(filled: true, color: ColorUtils.warning600),
            ],
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineRow(
                title: 'Terkirim',
                time: _fmtTime(sentAt),
                titleColor: ColorUtils.slate900,
              ),
              const SizedBox(height: 8),
              _TimelineRow(
                title: 'Diterima di app',
                time: deliveredAt == null ? 'belum' : _fmtTime(deliveredAt),
                titleColor: deliveredAt == null
                    ? ColorUtils.slate400
                    : ColorUtils.slate900,
              ),
              const SizedBox(height: 8),
              _TimelineRow(
                title: readAt == null ? 'Belum dibaca' : 'Dibaca',
                time: readAt == null ? '—' : _fmtTime(readAt),
                titleColor: readAt == null
                    ? ColorUtils.slate400
                    : ColorUtils.success600,
              ),
              if (repliedAt != null) ...[
                const SizedBox(height: 8),
                _TimelineRow(
                  title: 'Dibalas',
                  time: _fmtTime(repliedAt),
                  titleColor: ColorUtils.warning600,
                ),
                if (replyText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '"$replyText"',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _Dot({required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? color : ColorUtils.slate300,
          width: filled ? 0 : 1.5,
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1.5, height: 16, color: ColorUtils.slate200);
  }
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final String time;
  final Color titleColor;

  const _TimelineRow({
    required this.title,
    required this.time,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate500,
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
