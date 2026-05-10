// Bagikan ke Wali sheet — Frame H of
// `_design/teacher_rekomendasi_redesign.html`.
//
// Cobalt-themed AppDraggableSheet that lets the wali kelas / mengajar
// teacher fan a recommendation out to one or more parents. Body
// covers (top-down):
//   1. Penerima (recipient picker, tap to toggle)
//   2. Nada Pesan (tone chips: Hangat / Formal / Singkat / Detail)
//   3. Catatan Tambahan (optional textarea)
//   4. Pratinjau (live preview of the parent message)
//   5. Kanal Pengiriman (Push App always-on, WhatsApp opt-in)
//
// Footer is the standard `BottomSheetFooter` (Batal / Kirim ke n Wali).
//
// Sharing is gated server-side on the rec being post-approval (not
// pending / dismissed). The CTA on `RecommendationCard` only opens
// this sheet when that gate passes — so the sheet itself doesn't need
// to re-check.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

/// Public entry point. Returns `true` when the share completes; null
/// when dismissed; `false` on error so the caller can keep state.
Future<bool?> showRecommendationShareSheet({
  required BuildContext context,
  required Map<String, dynamic> recommendation,
  required String teacherId,
  required List<Map<String, dynamic>> availableParents,
  String? initialMessage,
  String? initialTone,
  bool initialChannelWhatsapp = false,
}) {
  return AppDraggableSheet.show<bool>(
    context: context,
    initialSize: 0.92,
    minSize: 0.6,
    maxSize: 0.96,
    builder: (sheetContext, scrollController) => _RecommendationShareSheet(
      recommendation: recommendation,
      teacherId: teacherId,
      availableParents: availableParents,
      initialMessage: initialMessage,
      initialTone: initialTone,
      initialChannelWhatsapp: initialChannelWhatsapp,
      scrollController: scrollController,
    ),
  );
}

class _RecommendationShareSheet extends StatefulWidget {
  final Map<String, dynamic> recommendation;
  final String teacherId;
  final List<Map<String, dynamic>> availableParents;
  final String? initialMessage;
  final String? initialTone;
  final bool initialChannelWhatsapp;
  final ScrollController scrollController;

  const _RecommendationShareSheet({
    required this.recommendation,
    required this.teacherId,
    required this.availableParents,
    required this.initialMessage,
    required this.initialTone,
    required this.initialChannelWhatsapp,
    required this.scrollController,
  });

  @override
  State<_RecommendationShareSheet> createState() =>
      _RecommendationShareSheetState();
}

class _RecommendationShareSheetState extends State<_RecommendationShareSheet> {
  static const _tones = <(String, String, String)>[
    ('hangat', '😊', 'Hangat'),
    ('formal', '📋', 'Formal'),
    ('singkat', '⚡', 'Singkat'),
    ('detail', '🎯', 'Detail'),
  ];

  late final Set<int> _selectedParents;
  late String _tone;
  late TextEditingController _messageCtrl;
  bool _channelWhatsapp = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Default: select every available parent.
    _selectedParents = {
      for (var i = 0; i < widget.availableParents.length; i++) i,
    };
    _tone = widget.initialTone ?? 'hangat';
    _messageCtrl = TextEditingController(text: widget.initialMessage ?? '');
    _channelWhatsapp = widget.initialChannelWhatsapp;
    _messageCtrl.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageCtrl.removeListener(_onMessageChanged);
    _messageCtrl.dispose();
    super.dispose();
  }

  void _onMessageChanged() => setState(() {});

  String get _studentName {
    final s = widget.recommendation['student'];
    if (s is Map) return (s['name'] ?? 'Siswa').toString();
    return widget.recommendation['student_name']?.toString() ?? 'Siswa';
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
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                _FieldLabel('Penerima'),
                const SizedBox(height: 6),
                _buildRecipientList(cobalt),
                const SizedBox(height: 14),
                _FieldLabel('Nada Pesan'),
                const SizedBox(height: 6),
                _buildToneGrid(cobalt),
                const SizedBox(height: 14),
                _FieldLabel('Catatan Tambahan', trailing: '· opsional'),
                const SizedBox(height: 6),
                _buildMessageInput(cobalt),
                const SizedBox(height: 14),
                _FieldLabel('Pratinjau Pesan'),
                const SizedBox(height: 6),
                _buildPreview(cobalt),
                const SizedBox(height: 14),
                _FieldLabel('Kanal Pengiriman'),
                const SizedBox(height: 6),
                _buildChannelRow(cobalt),
              ],
            ),
          ),
          BottomSheetFooter(
            primaryLabel: _submitting
                ? 'Mengirim...'
                : 'Kirim ke ${_selectedParents.length} Wali',
            primaryColor: cobalt,
            primaryEnabled: !_submitting && _selectedParents.isNotEmpty,
            onPrimary: _submit,
            onSecondary: _submitting
                ? () {}
                : () => Navigator.of(context).pop(null),
            secondaryLabel: 'Batal',
          ),
        ],
      ),
    );
  }

  Widget _buildGrabber() {
    return Center(
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
  }

  Widget _buildHeader(Color cobalt) {
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
            child: Icon(Icons.send_rounded, size: 16, color: cobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bagikan ke Wali',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_studentName · 1 rekomendasi',
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
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientList(Color cobalt) {
    if (widget.availableParents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Text(
          'Belum ada data wali untuk siswa ini.',
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.availableParents.length; i++) ...[
            if (i > 0) Container(height: 1, color: ColorUtils.slate100),
            _RecipientRow(
              parent: widget.availableParents[i],
              selected: _selectedParents.contains(i),
              cobalt: cobalt,
              onToggle: () {
                setState(() {
                  if (_selectedParents.contains(i)) {
                    _selectedParents.remove(i);
                  } else {
                    _selectedParents.add(i);
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToneGrid(Color cobalt) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _tones.map((entry) {
        final selected = _tone == entry.$1;
        return GestureDetector(
          onTap: () => setState(() => _tone = entry.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? cobalt.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? cobalt : ColorUtils.slate200,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              '${entry.$2} ${entry.$3}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? cobalt : ColorUtils.slate700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageInput(Color cobalt) {
    return TextField(
      controller: _messageCtrl,
      maxLines: 4,
      minLines: 3,
      style: TextStyle(fontSize: 12.5, color: ColorUtils.slate700, height: 1.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        hintText:
            'Mohon dampingi anak Bapak/Ibu mengerjakan rekomendasi ini di rumah…',
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: ColorUtils.slate400,
          height: 1.5,
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildPreview(Color cobalt) {
    final title = widget.recommendation['title']?.toString() ?? 'Rekomendasi';
    final message = _messageCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cobalt.withValues(alpha: 0.04),
            ColorUtils.brandAzure.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cobalt.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cobalt,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PESAN UNTUK WALI · KAMIL EDU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate700,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
              children: [
                const TextSpan(
                  text:
                      'Halo Bapak/Ibu, sebagai guru saya ingin berbagi rekomendasi belajar untuk ',
                ),
                TextSpan(
                  text: _studentName,
                  style: TextStyle(
                    color: ColorUtils.slate900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ':\n\n'),
                TextSpan(
                  text: title,
                  style: TextStyle(
                    color: ColorUtils.slate900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const TextSpan(text: '\n\n'),
                  TextSpan(
                    text: 'Catatan guru: ',
                    style: TextStyle(
                      color: cobalt,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: message),
                ],
                const TextSpan(text: '\n\n'),
                TextSpan(
                  text: 'Buka di aplikasi untuk melihat detail.',
                  style: TextStyle(color: cobalt, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(Color cobalt) {
    return Row(
      children: [
        Expanded(
          child: _ChannelChip(
            icon: Icons.notifications_active_rounded,
            label: 'Push App',
            selected: true,
            cobalt: cobalt,
            badge: '✓',
            onTap: () {
              SnackBarUtils.showInfo(
                context,
                'Push notifikasi akan selalu dikirim untuk kanal utama.',
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ChannelChip(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            selected: _channelWhatsapp,
            cobalt: cobalt,
            onTap: () => setState(() => _channelWhatsapp = !_channelWhatsapp),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedParents.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final parents = [
        for (final i in _selectedParents)
          {
            'parent_user_id': widget.availableParents[i]['parent_user_id'],
            'parent_name': widget.availableParents[i]['parent_name'] ?? 'Wali',
            'parent_phone': widget.availableParents[i]['parent_phone'],
            'parent_relation':
                widget.availableParents[i]['parent_relation'] ?? 'wali',
          },
      ];

      await getIt<ApiRecommendationService>().shareRecommendation(
        recommendationId: widget.recommendation['id'].toString(),
        teacherId: widget.teacherId,
        parents: parents,
        message: _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
        tone: _tone,
        channelPush: true,
        channelWhatsapp: _channelWhatsapp,
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Rekomendasi terkirim ke ${parents.length} wali.',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal mengirim: ${e.toString()}');
        setState(() => _submitting = false);
      }
    }
  }
}

class _RecipientRow extends StatelessWidget {
  final Map<String, dynamic> parent;
  final bool selected;
  final Color cobalt;
  final VoidCallback onToggle;

  const _RecipientRow({
    required this.parent,
    required this.selected,
    required this.cobalt,
    required this.onToggle,
  });

  String get _initials {
    final name = (parent['parent_name'] ?? 'W').toString().trim();
    if (name.isEmpty) return 'W';
    final bits = name.split(RegExp(r'\s+'));
    if (bits.length == 1) return bits.first.substring(0, 1).toUpperCase();
    return (bits.first.substring(0, 1) + bits.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final phone = parent['parent_phone']?.toString() ?? '';
    final relation = (parent['parent_relation'] ?? 'wali').toString();
    final hasUser = (parent['parent_user_id'] ?? '').toString().isNotEmpty;

    final sub = [
      relation[0].toUpperCase() + relation.substring(1),
      if (phone.isNotEmpty) phone,
      hasUser ? 'WA aktif' : 'belum login · push saja',
    ].join(' · ');

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cobalt.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
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
                    parent['parent_name']?.toString() ?? 'Wali',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? cobalt : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected ? cobalt : ColorUtils.slate300,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color cobalt;
  final String? badge;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.cobalt,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? cobalt.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cobalt : ColorUtils.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? cobalt : ColorUtils.slate500,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? cobalt : ColorUtils.slate500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(
                badge!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? cobalt : ColorUtils.slate500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? trailing;

  const _FieldLabel(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null)
            TextSpan(
              text: ' $trailing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}
