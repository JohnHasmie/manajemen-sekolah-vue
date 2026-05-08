// Lightweight Arabic shaper.
//
// Why this exists
// ---------------
// Syncfusion's PDF library doesn't run OpenType shaping (GSUB
// substitutions) for Arabic by default — it just emits the raw
// Unicode codepoints, so on the page each letter appears in its
// isolated form ("ا ل م ه ن ة" instead of the joined "المهنة").
//
// This shaper does the substitution manually before the PDF is
// drawn: it walks each rune, looks at its left/right neighbours
// to decide the form (isolated / initial / medial / final), and
// replaces the basic letter with the corresponding glyph from the
// Arabic Presentation Forms-B block (U+FE70–U+FEFF). It also
// handles the four Lam-Alef ligatures (ﻻ ﻼ etc.) which are a
// single glyph in the font.
//
// Coverage is the standard 28-letter Arabic alphabet plus hamza
// variants, teh marbuta, and alef maksura. Diacritics (harakat)
// are left untouched. Non-Arabic characters pass through unchanged
// so mixed Latin/Arabic strings work.
class ArabicShaper {
  /// Returns [input] with all Arabic letters replaced by their
  /// contextual presentation forms.
  static String shape(String input) {
    if (input.isEmpty) return input;

    final runes = input.runes.toList();
    final out = <int>[];

    for (var i = 0; i < runes.length; i++) {
      final cur = runes[i];

      // Non-Arabic → pass through.
      final forms = _forms[cur];
      if (forms == null) {
        out.add(cur);
        continue;
      }

      // Lam-Alef ligature: when current is Lam (U+0644) and next
      // is Alef-family, emit the ligature glyph and skip the alef.
      if (cur == 0x0644 && i + 1 < runes.length) {
        final lig = _lamAlefLigature(runes[i + 1], _joinsLeft(_prev(runes, i)));
        if (lig != 0) {
          out.add(lig);
          i++;
          continue;
        }
      }

      final prev = _prev(runes, i);
      final next = _next(runes, i);

      // "joinsLeft" of previous = previous letter joins to the
      // current → current's right side connects.
      // "joinsRight" of current  = current connects on the left
      // side → connects to next if next can also accept.
      final connectRight = _joinsLeft(prev);
      final connectLeft = _joinsRight(cur) && _joinsLeft(next) == false
          ? false
          : (_joinsRight(cur) && _isShaped(next));

      final form = _pickForm(connectRight, connectLeft);
      out.add(forms[form]);
    }

    return String.fromCharCodes(out);
  }

  /// Like [shape] but returns the result in VISUAL order (Arabic
  /// runs reversed) so it can be drawn with a plain LTR text engine
  /// and still read right-to-left.
  ///
  /// Why this exists: Syncfusion's `PdfTextDirection.rightToLeft`
  /// doesn't actually reverse our pre-shaped glyphs — it only
  /// shifts the start position to the right edge — so logical-order
  /// shaped text comes out in left-to-right glyph order, which
  /// reads as scrambled Arabic. By pre-reversing each Arabic run
  /// here and drawing with `textDirection: none`, we control the
  /// visual layout entirely and side-step Syncfusion's bidi.
  ///
  /// Diacritics (harakat) are kept attached to their base letter
  /// so they don't drift onto the wrong character after reversal.
  /// Latin / digits / punctuation runs are passed through unchanged.
  static String shapeRtl(String input) {
    if (input.isEmpty) return input;
    final shaped = shape(input).runes.toList();
    final out = <int>[];

    var i = 0;
    while (i < shaped.length) {
      if (_isArabicVisual(shaped[i])) {
        // Collect the contiguous Arabic run [i, j).
        var j = i;
        while (j < shaped.length && _isArabicVisual(shaped[j])) {
          j++;
        }
        // Build base+diacritic clusters in logical order, then
        // emit clusters in reverse so the first logical letter
        // ends up on the right edge of the run.
        final clusters = <List<int>>[];
        var k = i;
        while (k < j) {
          final cluster = <int>[shaped[k]];
          k++;
          while (k < j && _isHaraka(shaped[k])) {
            cluster.add(shaped[k]);
            k++;
          }
          clusters.add(cluster);
        }
        for (final c in clusters.reversed) {
          out.addAll(c);
        }
        i = j;
      } else {
        out.add(shaped[i]);
        i++;
      }
    }
    return String.fromCharCodes(out);
  }

  /// Codepoints that participate in an Arabic visual run for the
  /// purposes of [shapeRtl] — basic Arabic, supplements, and the
  /// Presentation Forms blocks that [shape] emits.
  static bool _isArabicVisual(int rune) {
    return (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
  }

  // ── Form selection ──

  static const _isolated = 0;
  static const _initial = 1;
  static const _medial = 2;
  static const _final = 3;

  static int _pickForm(bool connectRight, bool connectLeft) {
    if (connectRight && connectLeft) return _medial;
    if (connectRight) return _final;
    if (connectLeft) return _initial;
    return _isolated;
  }

  static int _prev(List<int> runes, int i) {
    for (var j = i - 1; j >= 0; j--) {
      final r = runes[j];
      if (_isHaraka(r)) continue; // skip diacritics
      return r;
    }
    return 0;
  }

  static int _next(List<int> runes, int i) {
    for (var j = i + 1; j < runes.length; j++) {
      final r = runes[j];
      if (_isHaraka(r)) continue;
      return r;
    }
    return 0;
  }

  static bool _isShaped(int rune) => _forms.containsKey(rune);

  /// True when [rune] can connect TO ITS LEFT — i.e. the next
  /// letter sees this letter as a connecting predecessor.
  static bool _joinsLeft(int rune) {
    if (rune == 0) return false;
    return _joinsLeftSet.contains(rune);
  }

  /// True when [rune] can connect TO ITS RIGHT — i.e. the previous
  /// letter is allowed to connect into this one.
  static bool _joinsRight(int rune) {
    if (rune == 0) return false;
    return _joinsRightSet.contains(rune);
  }

  static bool _isHaraka(int rune) {
    return (rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        (rune >= 0x06D6 && rune <= 0x06ED);
  }

  // ── Lam-Alef ligatures ──

  /// Returns the ligature glyph for Lam + given alef-form, or 0
  /// if [next] isn't an alef variant.
  /// FEFB/FEFC: lam-alef       (final / isolated forms)
  /// FEF7/FEF8: lam-alef-hamza-above
  /// FEF9/FEFA: lam-alef-hamza-below
  /// FEF5/FEF6: lam-alef-madda
  static int _lamAlefLigature(int next, bool prevJoins) {
    final iso = !prevJoins;
    switch (next) {
      case 0x0627: // ا
        return iso ? 0xFEFB : 0xFEFC;
      case 0x0623: // أ
        return iso ? 0xFEF7 : 0xFEF8;
      case 0x0625: // إ
        return iso ? 0xFEF9 : 0xFEFA;
      case 0x0622: // آ
        return iso ? 0xFEF5 : 0xFEF6;
    }
    return 0;
  }

  // ── Form table ──
  //
  // Each entry: [isolated, initial, medial, final].
  // Letters that only join from the right repeat their isolated
  // form for initial+medial and final form for final (no medial).
  static const Map<int, List<int>> _forms = {
    // hamza
    0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80],
    // alef madda
    0x0622: [0xFE81, 0xFE81, 0xFE82, 0xFE82],
    // alef hamza above
    0x0623: [0xFE83, 0xFE83, 0xFE84, 0xFE84],
    // waw hamza
    0x0624: [0xFE85, 0xFE85, 0xFE86, 0xFE86],
    // alef hamza below
    0x0625: [0xFE87, 0xFE87, 0xFE88, 0xFE88],
    // yeh hamza
    0x0626: [0xFE89, 0xFE8B, 0xFE8C, 0xFE8A],
    // alef
    0x0627: [0xFE8D, 0xFE8D, 0xFE8E, 0xFE8E],
    // beh
    0x0628: [0xFE8F, 0xFE91, 0xFE92, 0xFE90],
    // teh marbuta
    0x0629: [0xFE93, 0xFE93, 0xFE94, 0xFE94],
    // teh
    0x062A: [0xFE95, 0xFE97, 0xFE98, 0xFE96],
    // theh
    0x062B: [0xFE99, 0xFE9B, 0xFE9C, 0xFE9A],
    // jeem
    0x062C: [0xFE9D, 0xFE9F, 0xFEA0, 0xFE9E],
    // hah
    0x062D: [0xFEA1, 0xFEA3, 0xFEA4, 0xFEA2],
    // khah
    0x062E: [0xFEA5, 0xFEA7, 0xFEA8, 0xFEA6],
    // dal
    0x062F: [0xFEA9, 0xFEA9, 0xFEAA, 0xFEAA],
    // thal
    0x0630: [0xFEAB, 0xFEAB, 0xFEAC, 0xFEAC],
    // reh
    0x0631: [0xFEAD, 0xFEAD, 0xFEAE, 0xFEAE],
    // zain
    0x0632: [0xFEAF, 0xFEAF, 0xFEB0, 0xFEB0],
    // seen
    0x0633: [0xFEB1, 0xFEB3, 0xFEB4, 0xFEB2],
    // sheen
    0x0634: [0xFEB5, 0xFEB7, 0xFEB8, 0xFEB6],
    // sad
    0x0635: [0xFEB9, 0xFEBB, 0xFEBC, 0xFEBA],
    // dad
    0x0636: [0xFEBD, 0xFEBF, 0xFEC0, 0xFEBE],
    // tah
    0x0637: [0xFEC1, 0xFEC3, 0xFEC4, 0xFEC2],
    // zah
    0x0638: [0xFEC5, 0xFEC7, 0xFEC8, 0xFEC6],
    // ain
    0x0639: [0xFEC9, 0xFECB, 0xFECC, 0xFECA],
    // ghain
    0x063A: [0xFECD, 0xFECF, 0xFED0, 0xFECE],
    // feh
    0x0641: [0xFED1, 0xFED3, 0xFED4, 0xFED2],
    // qaf
    0x0642: [0xFED5, 0xFED7, 0xFED8, 0xFED6],
    // kaf
    0x0643: [0xFED9, 0xFEDB, 0xFEDC, 0xFEDA],
    // lam
    0x0644: [0xFEDD, 0xFEDF, 0xFEE0, 0xFEDE],
    // meem
    0x0645: [0xFEE1, 0xFEE3, 0xFEE4, 0xFEE2],
    // noon
    0x0646: [0xFEE5, 0xFEE7, 0xFEE8, 0xFEE6],
    // heh
    0x0647: [0xFEE9, 0xFEEB, 0xFEEC, 0xFEEA],
    // waw
    0x0648: [0xFEED, 0xFEED, 0xFEEE, 0xFEEE],
    // alef maksura
    0x0649: [0xFEEF, 0xFEEF, 0xFEF0, 0xFEF0],
    // yeh
    0x064A: [0xFEF1, 0xFEF3, 0xFEF4, 0xFEF2],
  };

  /// Letters that connect to the LEFT (i.e. their successor sees
  /// them as a connecting predecessor → successor takes medial/
  /// final form). All Arabic letters connect to the left EXCEPT
  /// the right-joining-only ones below.
  static final Set<int> _joinsLeftSet = {
    0x0626, // yeh hamza
    0x0628, // beh
    0x062A, // teh
    0x062B, // theh
    0x062C, // jeem
    0x062D, // hah
    0x062E, // khah
    0x0633, // seen
    0x0634, // sheen
    0x0635, // sad
    0x0636, // dad
    0x0637, // tah
    0x0638, // zah
    0x0639, // ain
    0x063A, // ghain
    0x0641, // feh
    0x0642, // qaf
    0x0643, // kaf
    0x0644, // lam
    0x0645, // meem
    0x0646, // noon
    0x0647, // heh
    0x0649, // alef maksura
    0x064A, // yeh
  };

  /// Letters that accept a connection FROM THE RIGHT — i.e. the
  /// previous letter is allowed to join into them. All Arabic
  /// letters accept this except the standalone hamza (U+0621).
  static final Set<int> _joinsRightSet = {
    for (final k in _forms.keys)
      if (k != 0x0621) k,
  };
}
