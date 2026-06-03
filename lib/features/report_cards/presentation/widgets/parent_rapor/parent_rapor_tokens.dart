// Shared brand tokens + predikat helpers for the parent report-card detail
// widgets.
//
// These were previously file-private constants/functions inside
// `parent_report_card_detail_widgets.dart`. The split into one-widget-per-file
// means the subject card and the deskripsi sheet need to share them, so they
// are promoted to public, library-level symbols here. Values are unchanged.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

// Brand tokens used across both score cells. Shared with the optional
// Deskripsi sheet.
const Color kParentRaporKi3 = Color(0xFF1B6FB8); // brandCobalt — Pengetahuan
const Color kParentRaporKi4 = Color(0xFF7C3AED); // violet600 — Keterampilan
const Color kParentRaporFailBg = Color(0xFFFEE2E2);
const Color kParentRaporFailFg = Color(0xFFB91C1C);
const Color kParentRaporFailBorder = Color(0x3FDC2626);
const Color kParentRaporPassBg = Color(0xFFDCFCE7);
const Color kParentRaporPassFg = Color(0xFF15803D);
const Color kParentRaporPassBorder = Color(0x3F16A34A);
const Color kParentRaporPartialBg = Color(0xFFFEF3C7);
const Color kParentRaporPartialFg = Color(0xFFB45309);
const Color kParentRaporPartialBorder = Color(0x3FD97706);

// Predikat → pill colors. Letter band derived from score using ≥90/≥80/≥70/<70.
({Color bg, Color fg}) parentRaporPredikatPill(String letter) {
  switch (letter) {
    case 'A':
      return (bg: const Color(0xFF16A34A), fg: Colors.white);
    case 'B':
      return (bg: kParentRaporKi3, fg: Colors.white);
    case 'C':
      return (bg: const Color(0xFFD97706), fg: Colors.white);
    case 'D':
    case 'E':
      return (bg: const Color(0xFFDC2626), fg: Colors.white);
    default:
      return (bg: ColorUtils.slate200, fg: ColorUtils.slate500);
  }
}

String parentRaporBandLetter(double v) {
  if (v >= 90) return 'A';
  if (v >= 80) return 'B';
  if (v >= 70) return 'C';
  if (v >= 60) return 'D';
  return 'E';
}

({Color bg, Color fg}) parentRaporLetterBadge(String letter) {
  switch (letter) {
    case 'A':
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
    case 'B':
      return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
    case 'C':
      return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
    case 'D':
      return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
    default:
      return (bg: ColorUtils.slate100, fg: ColorUtils.slate500);
  }
}
