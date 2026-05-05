// Bulk-delete confirmation dialog — used by every admin CRUD screen
// when the user taps the destructive action in [BulkActionBar].
//
// Mirrors the v3 actions mockup (frame F): danger circle + count, message
// body, multi-entity preview list (avatar + label per entity), and a
// type-to-confirm field that requires the literal string `HAPUS`. The
// confirm button stays disabled until the field matches exactly.
//
// Returns `true` via Navigator.pop when confirmed, `false`/null on cancel.
//
// Caller pattern:
// ```dart
// final ok = await showBulkDeleteConfirm(
//   context,
//   entityNoun: 'siswa',
//   items: selected.map((s) => BulkDeleteItem(
//     id: s['id'].toString(),
//     title: s['name'],
//     subtitle: 'Kelas ${s['class_name']}',
//     initials: nameInitials(s['name']),
//   )).toList(),
// );
// if (ok == true) await _bulkDelete();
// ```
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';

/// One row in the bulk-delete preview list.
class BulkDeleteItem {
  /// Unique id (used as a list key + by the caller's bulk-delete API).
  final String id;

  /// Primary label — entity name shown in bold.
  final String title;

  /// Secondary label — typically class / role / NIP / etc.
  final String? subtitle;

  /// Initials used for the small leading avatar. Defaults to first letter
  /// of [title] when null.
  final String? initials;

  const BulkDeleteItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.initials,
  });
}

/// Show the bulk-delete confirmation. The future resolves to `true` when
/// the user types `HAPUS` and taps the destructive button, `null` when
/// they dismiss the dialog.
Future<bool?> showBulkDeleteConfirm(
  BuildContext context, {
  required String entityNoun,
  required List<BulkDeleteItem> items,
  String confirmKeyword = 'HAPUS',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BulkDeleteConfirmDialog(
      entityNoun: entityNoun,
      items: items,
      confirmKeyword: confirmKeyword,
    ),
  );
}

class _BulkDeleteConfirmDialog extends StatefulWidget {
  final String entityNoun;
  final List<BulkDeleteItem> items;
  final String confirmKeyword;

  const _BulkDeleteConfirmDialog({
    required this.entityNoun,
    required this.items,
    required this.confirmKeyword,
  });

  @override
  State<_BulkDeleteConfirmDialog> createState() =>
      _BulkDeleteConfirmDialogState();
}

class _BulkDeleteConfirmDialogState extends State<_BulkDeleteConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().toUpperCase() == widget.confirmKeyword;

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final accent = const Color(0xFFDC2626); // danger red

    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Danger icon + count badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEE2E2),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Hapus $count ${widget.entityNoun} sekaligus?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Tindakan ini tidak bisa dibatalkan dan akan menghapus semua data terkait.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: ColorUtils.slate500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Entity preview list — caps at 4 visible, scrolls beyond.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.entityNoun.toUpperCase()} YANG AKAN DIHAPUS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _PreviewRow(item: widget.items[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Type-to-confirm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'KETIK "${widget.confirmKeyword}" UNTUK KONFIRMASI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.confirmKeyword,
                  hintStyle: TextStyle(
                    color: ColorUtils.slate400,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent, width: 1.6),
                  ),
                  suffixIcon: _matches
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: const Color(0xFF15803D),
                          size: 20,
                        )
                      : null,
                ),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: ColorUtils.slate200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => AppNavigator.pop(context, false),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: accent,
                        disabledBackgroundColor:
                            accent.withValues(alpha: 0.35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _matches
                          ? () => AppNavigator.pop(context, true)
                          : null,
                      child: Text(
                        'Hapus $count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final BulkDeleteItem item;
  const _PreviewRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item.initials ?? item.title;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: name,
            size: 26,
            color: ColorUtils.getRoleColor('admin'),
            borderRadius: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty)
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
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
