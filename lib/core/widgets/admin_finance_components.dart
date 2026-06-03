// Admin Keuangan hub shared components — Mockup #13.
//
// Barrel re-export. The individual widgets now live under
// `lib/core/widgets/finance/`, one public widget per file. This file is
// kept at its original path so existing importers keep working
// unchanged.
//
// Contents:
//   • MoneyFlowStrip       — 3 horizontal tiles inside the navy hero:
//                            Masuk · Terutang · Jatuh Tempo.
//   • FlowBar              — single-row stacked horizontal bar
//                            (paid / outstanding / overdue).
//   • MoneyFlowSkeleton    — loading placeholder for MoneyFlowStrip.
//   • formatRupiahCompact  — compact "Rp 184jt" formatter.
//   • adminFinanceGradient — admin brand gradient convenience.
//   • FinanceSubFilterStrip — Tagihan-tab sub-filter chip strip.
//   • InvoiceRow           — single invoice row.
//   • ClassReportDrillCard — drill-down card pinned at list bottom.
//   • BillGroupRow         — aggregated (payment_type × class) card.

export 'package:manajemensekolah/core/widgets/finance/money_flow_strip.dart';
export 'package:manajemensekolah/core/widgets/finance/flow_bar.dart';
export 'package:manajemensekolah/core/widgets/finance/money_flow_skeleton.dart';
export 'package:manajemensekolah/core/widgets/finance/finance_format_utils.dart';
export 'package:manajemensekolah/core/widgets/finance/finance_sub_filter_strip.dart';
export 'package:manajemensekolah/core/widgets/finance/invoice_row.dart';
export 'package:manajemensekolah/core/widgets/finance/class_report_drill_card.dart';
export 'package:manajemensekolah/core/widgets/finance/bill_group_row.dart';
