// Parent "Finance" tab root.
//
// Per `P1_BottomNav_Spec.md` § 2.3 — wali's Keuangan tab is a single
// screen (not a hub). The existing `ParentBillingScreen` already
// internally handles its own student picker + billing list, so the
// shell tab just wraps it directly.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';

class ParentFinanceTab extends StatelessWidget {
  const ParentFinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ParentBillingScreen();
  }
}
