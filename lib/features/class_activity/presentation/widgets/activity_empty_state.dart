// ActivityEmptyState — thin shim over the shared `BrandEmptyState`.
// Kept so older call sites (e.g. report-card or grade detail surfaces
// that haven't been touched yet) keep compiling. New code should use
// `BrandEmptyState` directly.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';

class ActivityEmptyState extends StatelessWidget {
  final String message;

  const ActivityEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return BrandEmptyState(
      icon: Icons.event_note_outlined,
      tone: BrandEmptyStateTone.info,
      kicker: 'Belum ada data',
      title: 'Belum ada aktivitas',
      message: message,
    );
  }
}
