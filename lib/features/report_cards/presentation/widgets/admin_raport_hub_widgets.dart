// Stateless / leaf-stateful sub-widgets for the admin Raport hub screen.
//
// Why this exists
// ---------------
// `admin_raport_hub_screen.dart` was carrying 9 sub-widgets in-file:
//   * `_BulkActionBar` + its `_BarButton` child (long-press selection bar)
//   * `_StatusFilterSheet` (filter modal)
//   * `_MoreMenuSheet` (overflow menu)
//   * `_BulkPublishSheet` + `_BulkPublishSheetState` (confirm sheet with
//     a notification toggle)
//   * `_ImpactCard` (used inside the publish sheet)
//   * `_RaportInfoCard` (error / empty placeholder)
//
// None of them touch the screen's controller state — they all take
// callbacks and primitives as input. Pulling them into a co-located
// widgets file collapses the screen file by ~770 lines without
// changing visual behaviour.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Status filter keys used both by the pipeline strip and the chip
/// strip. `'all'` means "show everything".
const adminRaportStatusKeys = [
  'all',
  'draft',
  'reviewed',
  'published',
  'distributed',
];

const adminRaportStatusLabels = {
  'all': 'Semua',
  'draft': 'Draft',
  'reviewed': 'Diperiksa',
  'published': 'Terbit',
  'distributed': 'Dibagikan',
};

// ═════════════════════════════════════════════════════════════════════
// Bulk action bar — sticky bottom bar for the long-press selection mode
// ═════════════════════════════════════════════════════════════════════

class AdminRaportBulkActionBar extends StatelessWidget {
  final int count;
  final String selectedLabels;
  final bool publishing;
  final VoidCallback onCetak;
  final VoidCallback onTerbit;
  final VoidCallback onClear;

  const AdminRaportBulkActionBar({
    super.key,
    required this.count,
    required this.selectedLabels,
    required this.publishing,
    required this.onCetak,
    required this.onTerbit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
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
                  '$count kelas dipilih',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedLabels,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BarButton(
            label: 'Cetak',
            filled: false,
            onTap: publishing ? null : onCetak,
          ),
          const SizedBox(width: 6),
          _BarButton(
            label: publishing ? 'Menerbitkan…' : 'Terbit',
            filled: true,
            loading: publishing,
            onTap: publishing ? null : onTerbit,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _BarButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        filled ? navy : Colors.white,
                      ),
                    ),
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: filled ? navy : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Status filter sheet
// ═════════════════════════════════════════════════════════════════════

class AdminRaportStatusFilterSheet extends StatelessWidget {
  final String active;
  final ValueChanged<String> onPick;

  const AdminRaportStatusFilterSheet({
    super.key,
    required this.active,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, color: navy, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter status raport',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Pilih satu status — body daftar tingkat akan disaring '
                'otomatis.',
                style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            for (final key in adminRaportStatusKeys)
              ListTile(
                onTap: () => onPick(key),
                leading: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconForStatus(key), color: navy, size: 16),
                ),
                title: Text(
                  adminRaportStatusLabels[key] ?? key,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                trailing: key == active
                    ? Icon(Icons.check_circle_rounded, color: navy)
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: ColorUtils.slate300,
                      ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _iconForStatus(String key) {
    switch (key) {
      case 'draft':
        return Icons.edit_note_rounded;
      case 'reviewed':
        return Icons.task_alt_rounded;
      case 'published':
        return Icons.send_rounded;
      case 'distributed':
        return Icons.share_rounded;
      default:
        return Icons.all_inclusive_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════
// More-menu sheet
// ═════════════════════════════════════════════════════════════════════

class AdminRaportMoreMenuSheet extends StatelessWidget {
  final Color navy;
  final VoidCallback onRefresh;
  final VoidCallback onCetak;
  final VoidCallback? onClearFilter;

  const AdminRaportMoreMenuSheet({
    super.key,
    required this.navy,
    required this.onRefresh,
    required this.onCetak,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print_rounded, color: navy, size: 16),
              ),
              title: const Text(
                'Cetak raport',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Buka alur cetak per kelas',
                style: TextStyle(fontSize: 10.5),
              ),
              onTap: onCetak,
            ),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.refresh_rounded, color: navy, size: 16),
              ),
              title: const Text(
                'Muat ulang data',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: const Text(
                'Ambil pipeline + kelas terbaru dari server',
                style: TextStyle(fontSize: 10.5),
              ),
              onTap: onRefresh,
            ),
            if (onClearFilter != null)
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.filter_alt_off_rounded,
                    color: navy,
                    size: 16,
                  ),
                ),
                title: const Text(
                  'Bersihkan filter',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Tampilkan semua status',
                  style: TextStyle(fontSize: 10.5),
                ),
                onTap: onClearFilter,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Bulk publish confirm sheet — returns true on confirm, null on cancel
// ═════════════════════════════════════════════════════════════════════

class AdminRaportBulkPublishSheet extends StatefulWidget {
  final Color navy;
  final int classCount;
  final String classNames;
  final String tingkatLabel;
  final int studentCount;

  const AdminRaportBulkPublishSheet({
    super.key,
    required this.navy,
    required this.classCount,
    required this.classNames,
    required this.tingkatLabel,
    required this.studentCount,
  });

  @override
  State<AdminRaportBulkPublishSheet> createState() =>
      _AdminRaportBulkPublishSheetState();
}

class _AdminRaportBulkPublishSheetState
    extends State<AdminRaportBulkPublishSheet> {
  bool _sendNotification = true;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorUtils.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.navy, widget.navy.withValues(alpha: 0.85)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TERBITKAN RAPOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.classCount} kelas siap terbit',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.tingkatLabel} · ${widget.classNames} · '
                  '${widget.studentCount} siswa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAMPAK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _ImpactCard(
                  title: 'Notifikasi otomatis',
                  subtitle:
                      '${widget.studentCount} wali murid akan menerima push',
                  color: ColorUtils.slate100,
                  textColor: ColorUtils.slate900,
                ),
                const SizedBox(height: 8),
                _ImpactCard(
                  title: 'Akses parent role',
                  subtitle: 'Rapor lengkap + ringkasan terbuka',
                  color: ColorUtils.slate100,
                  textColor: ColorUtils.slate900,
                ),
                const SizedBox(height: 8),
                const _ImpactCard(
                  title: 'Tindakan tidak dapat dibatalkan',
                  subtitle: 'Ubah ke Diperiksa harus manual per kelas',
                  color: Color(0xFFFFFBEB),
                  textColor: Color(0xFF92400E),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kirim notifikasi push',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Wali murid akan menerima alert',
                              style: TextStyle(
                                fontSize: 10,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _sendNotification,
                        onChanged: (v) => setState(() => _sendNotification = v),
                        activeTrackColor: widget.navy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: ColorUtils.slate300),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Terbitkan ${widget.classCount} kelas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;

  const _ImpactCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Info card (error / empty)
// ═════════════════════════════════════════════════════════════════════

class AdminRaportInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onRetry;

  const AdminRaportInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
    required this.onRetry,
    this.actionLabel = 'Muat ulang',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
