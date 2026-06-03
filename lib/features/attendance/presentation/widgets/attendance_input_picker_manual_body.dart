// Manual-tab body + footer for the Ambil Presensi sheet — extracted
// from `attendance_input_picker_sheet.dart` as a `part` so the
// orchestrator stays focused on state + flow. Behavior-preserving:
// these are the same `_AmbilPresensiSheetState` methods, moved
// verbatim into an extension on the State class.
//
// The off-schedule fallback path: date picker + class chips + subject
// chips (lazily fetched per class via `_fetchManualSubjects`), plus
// the pinned Cancel / "Mulai Absen" footer that commits the pick via
// `_applyManual`.
part of 'attendance_input_picker_sheet.dart';

extension _AmbilPresensiSheetManualBody on _AmbilPresensiSheetState {
  // ── Manual tab body ──
  // setState-touching mutators (`_setManualDate`, `_selectManualClass`,
  // `_selectManualSubject`) live on the state class because extensions
  // can't call the protected `setState`.

  Widget _manualBody() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      children: [
        _fieldGroup(
          label: widget.lp.getTranslatedText({'en': 'Date', 'id': 'Tanggal'}),
          child: _datePicker(),
        ),
        _fieldGroup(
          label: widget.lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          child: _classChips(),
        ),
        _fieldGroup(
          label: widget.lp.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          child: _subjectChips(),
        ),
      ],
    );
  }

  Widget _fieldGroup({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _manualDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) _setManualDate(picked);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          border: Border.all(color: ColorUtils.slate200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: ColorUtils.slate400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('EEE, d MMM yyyy', 'id_ID').format(_manualDate),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: ColorUtils.slate400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _classChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in widget.classList)
          if (c is Map)
            _chip(
              label: (c['name'] ?? c['nama'] ?? '-').toString(),
              selected: _manualClassId == (c['id'] ?? '').toString(),
              onTap: () {
                final cid = (c['id'] ?? '').toString();
                final cname = (c['name'] ?? c['nama'] ?? '').toString();
                _selectManualClass(cid, cname);
                _fetchManualSubjects(cid);
              },
            ),
      ],
    );
  }

  Widget _subjectChips() {
    if (_manualClassId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'Pick a class first.',
            'id': 'Pilih kelas terlebih dulu.',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    if (_loadingSubjects) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'Loading subjects…',
            'id': 'Memuat mapel…',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    if (_manualSubjectList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'No subjects assigned for this class.',
            'id': 'Tidak ada mapel untuk kelas ini.',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in _manualSubjectList)
          if (s is Map)
            _chip(
              label: (s['name'] ?? s['nama'] ?? '-').toString(),
              selected: _manualSubjectId == (s['id'] ?? '').toString(),
              onTap: () {
                _selectManualSubject(
                  (s['id'] ?? '').toString(),
                  (s['name'] ?? s['nama'] ?? '').toString(),
                );
              },
            ),
      ],
    );
  }

  /// Compact chip — sized to its label, not greedy. Earlier the chips
  /// rendered as full-width pills because the AnimatedContainer used
  /// `alignment: Alignment.center` which makes Container expand to the
  /// parent's intrinsic width. Replaced with a Material+InkWell wrap
  /// around `Padding > Text` so the chip hugs its content and Wrap
  /// can lay multiple chips per row.
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? ColorUtils.brandCobalt.withValues(alpha: 0.10)
                : ColorUtils.slate50,
            border: Border.all(
              color: selected ? ColorUtils.brandCobalt : ColorUtils.slate200,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? ColorUtils.brandCobalt : ColorUtils.slate700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualFooter() {
    final canApply = _manualClassId != null && _manualSubjectId != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorUtils.slate700,
                    side: BorderSide(color: ColorUtils.slate200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    widget.lp.getTranslatedText({
                      'en': 'Cancel',
                      'id': 'Batal',
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: canApply ? _applyManual : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: Text(
                    widget.lp.getTranslatedText({
                      'en': 'Start',
                      'id': 'Mulai Absen',
                    }),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.brandCobalt,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ColorUtils.slate200,
                    disabledForegroundColor: ColorUtils.slate500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
