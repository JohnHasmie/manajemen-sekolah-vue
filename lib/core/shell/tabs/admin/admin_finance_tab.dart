// Admin "Finance" tab root.
//
// The admin Finance Hub (`FinanceScreen`) is already a 4-tab hub of its
// own (Dasbor / Jenis Pembayaran / Verifikasi / Laporan Kelas) after the
// Phase 2 Keuangan refactor. The shell tab just renders it directly so
// callers don't accidentally pile on another layer of navigation.
//
// Per `P1_BottomNav_Spec.md` § 2.1.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';

class AdminFinanceTab extends StatelessWidget {
  const AdminFinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinanceScreen();
  }
}
