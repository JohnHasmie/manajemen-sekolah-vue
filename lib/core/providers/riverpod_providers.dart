/// riverpod_providers.dart - Riverpod provider definitions wrapping existing ChangeNotifiers.
/// Like re-exporting a Vuex store module as a Pinia store.
///
/// This bridges the existing Provider-based ChangeNotifiers (LanguageProvider,
/// AcademicYearProvider, TeacherProvider) into Riverpod's provider system.
///
/// Screens can gradually migrate from:
///   `Provider.of<AcademicYearProvider>(context, listen: false)`
/// to:
///   `ref.read(academicYearProvider)`
///
/// Both work simultaneously during the migration period.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/core/providers/teacher_provider.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Riverpod provider for [AcademicYearProvider].
/// Wraps the existing ChangeNotifier so both old and new code can access it.
///
/// Usage: `ref.watch(academicYearRiverpod)` or `ref.read(academicYearRiverpod)`
final academicYearRiverpod = riverpod.ChangeNotifierProvider<AcademicYearProvider>((ref) {
  return AcademicYearProvider();
});

/// Riverpod provider for [TeacherProvider].
/// Usage: `ref.watch(teacherRiverpod)` or `ref.read(teacherRiverpod)`
final teacherRiverpod = riverpod.ChangeNotifierProvider<TeacherProvider>((ref) {
  return TeacherProvider();
});

/// Riverpod provider for [LanguageProvider].
/// Uses the existing global singleton instance to stay in sync with
/// the `.tr` extension and old Provider-based widgets.
///
/// Usage: `ref.watch(languageRiverpod)` for reactive language changes
final languageRiverpod = riverpod.ChangeNotifierProvider<LanguageProvider>((ref) {
  return languageProvider; // Global singleton from language_utils.dart
});
