// Perlu Perhatian — full-screen "Lihat Semua" inbox.
//
// Phase-5 surface B. Reached from the "Lihat semua" link on the
// parent dashboard's Perlu Perhatian card. Lists every parent-
// relevant attention item across categories (Tagihan, Nilai,
// Pengumuman, Kehadiran, Aktivitas, Raport), grouped by date.
//
// Key design choices vs the dashboard inbox card:
//   • All categories interleaved (the card's per-row tiles are
//     summary-by-category; this screen is the per-item drill-down).
//   • Filter chips horizontally scroll: Semua / Tagihan / Nilai / …
//     each with a count badge from the backend.
//   • Date groups: HARI INI / KEMARIN / MINGGU INI / LEBIH LAMA.
//   • No "Tandai semua" action — items are action items, not
//     notifications. Tapping a row routes to the relevant detail
//     and the row is naturally consumed when the action completes.
//
// Backend: GET /dashboard/parent-inbox?category=…&limit=…
// Returns `{ items, counts }` where counts power the chip badges.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';

class ParentInboxScreen extends ConsumerStatefulWidget {
  const ParentInboxScreen({super.key});

  @override
  ConsumerState<ParentInboxScreen> createState() => _ParentInboxScreenState();
}

class _ParentInboxScreenState extends ConsumerState<ParentInboxScreen> {
  /// Selected filter chip — server-side category key.
  String _category = 'all';

  /// Latest fetch.
  List<_InboxItem> _items = const [];
  Map<String, int> _counts = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await DashboardService.getParentInbox(category: _category);
    if (!mounted) return;
    setState(() {
      _items = result.items.map(_InboxItem.fromJson).toList(growable: false);
      _counts = result.counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(_items);
    final totalUnread = _counts['all'] ?? 0;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _load,
        color: ColorUtils.brandAzure,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(totalUnread)),
            SliverToBoxAdapter(child: _buildFilterChips()),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: BrandEmptyState(
                    icon: Icons.inbox_outlined,
                    tone: BrandEmptyStateTone.info,
                    kicker: 'Tidak ada item',
                    title: 'Bersih untuk sekarang',
                    message: _category == 'all'
                        ? 'Belum ada hal yang perlu perhatian Anda di sekolah ini.'
                        : 'Tidak ada item di kategori ini.',
                  ),
                ),
              )
            else
              ..._buildSliverGroups(groups),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  // ─────────────── pieces ───────────────

  Widget _buildHero(int totalUnread) {
    final statusBar = MediaQuery.of(context).viewPadding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandAzure, ColorUtils.brandAzureDeep],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        statusBar + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => AppNavigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Beranda · Anak',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Perlu Perhatian',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Counter chip — replaces the "Tandai semua" action
          // since these are action items, not notifications.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              totalUnread > 0
                  ? '$totalUnread belum dibaca'
                  : 'Tidak ada item baru',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <(String key, String label)>[
      ('all', 'Semua'),
      ('tagihan', 'Tagihan'),
      ('nilai', 'Nilai'),
      ('pengumuman', 'Pengumuman'),
      ('kehadiran', 'Kehadiran'),
      ('aktivitas', 'Aktivitas'),
      ('raport', 'Raport'),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          final isActive = c.$1 == _category;
          final count = _counts[c.$1] ?? 0;
          return _FilterChip(
            label: c.$2,
            count: count,
            active: isActive,
            onTap: () {
              if (c.$1 == _category) return;
              setState(() => _category = c.$1);
              _load();
            },
          );
        },
      ),
    );
  }

  /// Group items into HARI INI / KEMARIN / MINGGU INI / LEBIH LAMA
  /// using the parsed `created_at` ISO string. Items without a date
  /// fall into "Lainnya" at the bottom.
  Map<String, List<_InboxItem>> _groupByDate(List<_InboxItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 7));

    final groups = <String, List<_InboxItem>>{
      'HARI INI': [],
      'KEMARIN': [],
      'MINGGU INI': [],
      'LEBIH LAMA': [],
    };

    for (final item in items) {
      final created = item.createdAt;
      if (created == null) {
        groups['LEBIH LAMA']!.add(item);
        continue;
      }
      final d = DateTime(created.year, created.month, created.day);
      if (d == today) {
        groups['HARI INI']!.add(item);
      } else if (d == yesterday) {
        groups['KEMARIN']!.add(item);
      } else if (d.isAfter(weekStart)) {
        groups['MINGGU INI']!.add(item);
      } else {
        groups['LEBIH LAMA']!.add(item);
      }
    }
    // Drop empty groups so the UI doesn't render dead headers.
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  List<Widget> _buildSliverGroups(Map<String, List<_InboxItem>> groups) {
    final out = <Widget>[];
    groups.forEach((label, items) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      );
      out.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _InboxRow(item: items[i]),
            ),
            childCount: items.length,
          ),
        ),
      );
    });
    return out;
  }
}

// ════════════════════════════════════════════════════════════════════
//  Row + chip + model
// ════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? ColorUtils.brandAzureDeep : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: active
                ? null
                : Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : ColorUtils.slate600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white.withValues(alpha: 0.7)
                        : ColorUtils.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final _InboxItem item;

  const _InboxRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accentColor;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.category == 'tagihan' && !item.isRead
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFE2E8F0),
              width: item.category == 'tagihan' && !item.isRead ? 1 : 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, color: accent, size: 18),
              ),
              AppSpacing.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title.isEmpty ? '—' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                    if (item.extra.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.extra,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.timeAgo,
                    style: TextStyle(fontSize: 9.5, color: ColorUtils.slate400),
                  ),
                  const SizedBox(height: 8),
                  if (!item.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// For now tapping a row pops back to the dashboard so the user
  /// can use the existing per-feature deep links (Tagihan tab, Nilai
  /// tab, etc.). Per-row routing to detail screens is a follow-up.
  void _onTap(BuildContext context) {
    AppNavigator.pop(context);
  }
}

/// Strongly-typed view model for a parent-inbox row.
class _InboxItem {
  final String id;
  final String type;
  final String category;
  final String title;
  final String subtitle;
  final String extra;
  final String timeAgo;
  final DateTime? createdAt;
  final bool isRead;

  const _InboxItem({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.extra,
    required this.timeAgo,
    required this.createdAt,
    required this.isRead,
  });

  factory _InboxItem.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at']?.toString();
    if (raw != null && raw.isNotEmpty) {
      created = DateTime.tryParse(raw);
    }
    return _InboxItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      category: json['category']?.toString() ?? 'lainnya',
      title: json['title']?.toString() ?? '',
      subtitle:
          json['subtitle']?.toString() ?? json['source']?.toString() ?? '',
      extra: json['extra']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? '',
      createdAt: created,
      isRead: json['is_read'] == true,
    );
  }

  /// Per-category icon — matches the dashboard's PendingInboxCard
  /// icon set so the brand language is consistent.
  IconData get icon {
    switch (category) {
      case 'tagihan':
        return Icons.account_balance_wallet_outlined;
      case 'nilai':
        return Icons.bar_chart_rounded;
      case 'pengumuman':
        return Icons.campaign_outlined;
      case 'kehadiran':
        return Icons.directions_run_rounded;
      case 'aktivitas':
        return Icons.assignment_outlined;
      case 'raport':
        return Icons.menu_book_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Accent colour driven by category. Tagihan = danger red,
  /// nilai = indigo, pengumuman = brand-azure, kehadiran = warning
  /// amber, aktivitas = success green, raport = brand-azure.
  Color get accentColor {
    switch (category) {
      case 'tagihan':
        return ColorUtils.error600;
      case 'nilai':
        return const Color(0xFF6366F1);
      case 'pengumuman':
        return ColorUtils.brandAzureDeep;
      case 'kehadiran':
        return ColorUtils.warning600;
      case 'aktivitas':
        return ColorUtils.success600;
      case 'raport':
        return ColorUtils.brandAzureDeep;
      default:
        return ColorUtils.slate500;
    }
  }
}
