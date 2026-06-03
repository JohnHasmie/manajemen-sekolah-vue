// Context strip rendered in the header's bottom slot on the teacher
// activity-detail screen.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState._contextStrip`
// (plus its `_clipTime` helper). Shows the subject letter avatar, the
// activity title, and a `subject · class · day · time` subtitle over the
// brand gradient header.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Subject-avatar + title + meta row shown inside the gradient header.
///
/// Takes the merged activity map [a] (list-row payload overlaid with the
/// fetched detail) and reads the same fallback key pairs the original did.
class ActivityDetailContextStrip extends StatelessWidget {
  final Map<String, dynamic> a;

  const ActivityDetailContextStrip({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final subject = (a['subject_name'] ?? a['mata_pelajaran_nama'] ?? '-')
        .toString();
    final klass = (a['class_name'] ?? a['kelas_nama'] ?? '-').toString();
    final title = (a['title'] ?? a['judul'] ?? '-').toString();
    final dateStr = (a['date'] ?? a['tanggal'] ?? '').toString();
    final timeStr = (a['time'] ?? a['jam'] ?? '').toString();
    final initial = subject.isNotEmpty ? subject[0].toUpperCase() : '?';

    final subParts = <String>[];
    final d = DateTime.tryParse(dateStr);
    if (d != null) {
      subParts.add(DateFormat('EEEE, d MMM', 'id_ID').format(d));
    }
    if (timeStr.isNotEmpty) subParts.add(_clipTime(timeStr));
    final subSuffix = subParts.isEmpty ? '' : ' · ${subParts.join(' · ')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: ColorUtils.brandCobalt,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subject · $klass$subSuffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clipTime(String s) {
    if (s.length >= 5) return s.substring(0, 5).replaceAll(':', '.');
    return s.replaceAll(':', '.');
  }
}
