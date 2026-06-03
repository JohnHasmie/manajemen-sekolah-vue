// Finance formatting helpers shared by the admin Keuangan hub — a
// compact rupiah formatter and the admin gradient convenience.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Returns a compact "Rp 184jt" / "Rp 1,2M" / "Rp 28rb" label.
/// Returns "Rp 0" for null / non-positive inputs.
String formatRupiahCompact(num? value) {
  final v = (value ?? 0).toDouble();
  if (v <= 0) return 'Rp 0';
  final abs = v.abs();
  String body;
  if (abs >= 1e9) {
    body = '${(abs / 1e9).toStringAsFixed(abs >= 10e9 ? 0 : 1)}M';
  } else if (abs >= 1e6) {
    body = '${(abs / 1e6).toStringAsFixed(abs >= 10e6 ? 0 : 1)}jt';
  } else if (abs >= 1e3) {
    body = '${(abs / 1e3).toStringAsFixed(abs >= 10e3 ? 0 : 1)}rb';
  } else {
    body = abs.toStringAsFixed(0);
  }
  // Trim trailing ".0" for cleaner display ("184jt" not "184.0jt").
  body = body.replaceAll(RegExp(r'\.0(?=[a-zA-Z])'), '');
  return 'Rp $body';
}

// Re-export ColorUtils admin gradient as a convenience so screens
// that import this file don't also need to import color_utils.
LinearGradient adminFinanceGradient() => ColorUtils.brandGradient('admin');
