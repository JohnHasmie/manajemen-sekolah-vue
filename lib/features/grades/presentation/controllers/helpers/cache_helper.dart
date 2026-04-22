import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';

/// Helper for building cache keys for classes and subjects.
class CacheHelper {
  /// Builds cache key for class list, or null if caching
  /// should be skipped (pagination or search).
  static String? buildClassCacheKey(
    int page,
    String query,
    Ref ref,
    dynamic teacherId,
  ) {
    if (page != 1 || query.trim().isNotEmpty) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'grade_classes_${teacherId}_$yearId';
  }

  /// Builds cache key for subject list.
  static String? buildSubjectCacheKey(
    Map<String, dynamic> classData,
    Ref ref,
    dynamic teacherId,
  ) {
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'grade_subjects_${teacherId}_${classData['id']}_$yearId';
  }

  /// Builds cache key for schedule list.
  static String buildScheduleCacheKey(
    dynamic teacherId,
    String semester,
    String? academicYearId,
  ) {
    return CacheKeyBuilder.custom(
      'schedule_teacher',
      '${teacherId}_$semester',
      academicYearId,
    );
  }
}
