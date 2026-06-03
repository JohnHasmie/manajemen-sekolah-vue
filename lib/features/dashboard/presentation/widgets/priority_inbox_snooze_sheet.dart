// GG.9 — local snooze sheet for the teacher Priority Inbox.
//
// Surfaces on long-press of any row in the dashboard card OR the
// full-screen inbox (Phase 2A). Offers two presets:
//   • "Sampai besok pagi (06:00)" — clears at 6 AM local
//   • "Sembunyikan 8 jam"        — clears at now+8h
//
// On confirm the [PriorityInboxSnoozeStore] persists the choice to
// SharedPreferences and the entry-point helper returns `true` so
// the caller can re-filter its list. On dismiss it returns `null`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/dashboard/data/priority_inbox_snooze_store.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';

/// Open the snooze sheet for [item]. Returns `true` if the user
/// snoozed (caller should refresh the list), `null` otherwise.
Future<bool?> showPriorityInboxSnoozeSheet({
  required BuildContext context,
  required PriorityInboxItem item,
}) {
  return AppBottomSheet.show<bool>(
    context: context,
    title: 'Sembunyikan sementara',
    subtitle: item.label,
    icon: Icons.snooze_rounded,
    primaryColor: ColorUtils.brandCobalt,
    content: _SnoozeContent(item: item),
    contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
  );
}

class _SnoozeContent extends StatelessWidget {
  final PriorityInboxItem item;

  const _SnoozeContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Item ini akan hilang sementara dari daftar Perlu Perhatian — '
          'hanya di perangkat ini.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: 16),
        for (final d in SnoozeDuration.values) ...[
          _SnoozeOption(
            duration: d,
            onTap: () async {
              await PriorityInboxSnoozeStore.instance.snoozeWith(item.id, d);
              if (context.mounted) AppNavigator.pop(context, true);
            },
          ),
          if (d != SnoozeDuration.values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SnoozeOption extends StatelessWidget {
  final SnoozeDuration duration;
  final VoidCallback onTap;

  const _SnoozeOption({required this.duration, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFirst = duration == SnoozeDuration.untilMorning;
    final icon = isFirst
        ? Icons.wb_twilight_rounded
        : Icons.hourglass_bottom_rounded;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ColorUtils.brandCobalt.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: ColorUtils.brandCobalt, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  duration.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
