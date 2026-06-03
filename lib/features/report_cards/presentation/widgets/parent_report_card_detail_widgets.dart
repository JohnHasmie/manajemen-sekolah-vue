// Stateless presentation widgets for the parent report-card detail screen.
//
// Why this exists
// ---------------
// The detail screen used to inline 16 sub-widgets — KPI strip, sikap card,
// per-subject card, ekstra/prestasi cards, attendance breakdown, decision
// banner, and so on — making the file 1700+ lines and hostile to change.
// All of them are stateless and depend only on the rapor payload, so they
// pull cleanly into a single co-located widgets family.
//
// This file is now a barrel: each widget lives in its own file under
// `widgets/parent_rapor/`, and they are re-exported here so every existing
// importer (`parent_report_card_detail_screen.dart` and
// `report_card_ui_builder_mixin.dart`) keeps working unchanged.
//
// Naming convention
// -----------------
// Each widget is prefixed `ParentRapor` to avoid collisions with the
// admin/teacher rapor screens, which carry their own card families.
// Imports from outside the report-cards feature should be considered
// internal — this file is not a shared design-system surface.
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_achievements_card.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_attendance_card.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_bottom_action_bar.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_decision_banner.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_deskripsi_sheet.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_empty_hint.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_export_note.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_extras_card.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_ganjil_decision_note.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_hero_chip.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_kpi_strip.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_notes_card.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_section_header.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_sikap_card.dart';
export 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_subject_card.dart';
