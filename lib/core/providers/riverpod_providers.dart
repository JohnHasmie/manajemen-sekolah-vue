/// riverpod_providers.dart - Re-exports feature-based providers for backward
/// compatibility.
///
/// As part of the Feature-First refactoring, providers were moved to their
/// respective features. This file serves as a legacy barrel to prevent
/// breaking existing imports while code is migrated.
library;

export 'package:manajemensekolah/core/utils/language_utils.dart'
    show languageRiverpod;
export 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart'
    show academicYearRiverpod;
export 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart'
    show teacherRiverpod;
export 'package:manajemensekolah/features/filter_roster/presentation/providers/filter_roster_provider.dart'
    show filterRosterRiverpod, FilterRosterProvider;
