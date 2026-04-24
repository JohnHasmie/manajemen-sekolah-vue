import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Mixin for UI helper methods in TeacherDetailScreen.
mixin TeacherDetailUIHelpersMixin {
  /// Maps object lists or IDs to display names.
  List<String> getNamesList(
    dynamic objects,
    dynamic ids,
    List<dynamic> sourceList,
  ) {
    if (objects != null && objects is List && objects.isNotEmpty) {
      return objects
          .map((item) => item['name']?.toString() ?? 'Unknown')
          .toList();
    }
    if (ids == null) return [];
    List<String> idList = [];
    if (ids is List) {
      idList = ids.map((e) => e.toString()).toList();
    } else if (ids is String && ids.isNotEmpty) {
      idList = ids.split(',').map((e) => e.trim()).toList();
    }
    return idList.map((id) {
      final item = sourceList.firstWhere(
        (element) => element['id'].toString() == id,
        orElse: () => {'name': 'Unknown'},
      );
      return item['name']?.toString() ?? 'Unknown';
    }).toList();
  }

  /// Extracts teaching class names from teaching schedules.
  List<String> extractTeachingClassNames(Map<String, dynamic>? teacher) {
    if (teacher == null) return [];

    if (teacher['teaching_schedules'] != null &&
        teacher['teaching_schedules'] is List) {
      final schedules = teacher['teaching_schedules'] as List;
      final uniqueClassNames = <String>{};
      for (final schedule in schedules) {
        final model = Schedule.fromJson(schedule as Map<String, dynamic>);
        if (model.className != null) {
          uniqueClassNames.add(model.className!);
        }
      }
      return uniqueClassNames.toList()..sort();
    }
    return [];
  }

  /// Determines homeroom class status string.
  String getHomeroomStatus(Map<String, dynamic>? teacher) {
    if (teacher == null) return '-';

    // Check homeroomClasses (plural) from new backend
    if (teacher['homeroom_classes'] != null &&
        teacher['homeroom_classes'] is List &&
        (teacher['homeroom_classes'] as List).isNotEmpty) {
      final classes = teacher['homeroom_classes'] as List;
      final names = classes
          .where((c) => c['name'] != null)
          .map((c) => c['name'].toString())
          .toList();

      if (names.isNotEmpty) {
        return 'Ya, Kelas ${names.join(", ")}';
      }
    }

    // Fallback to legacy single 'homeroom_class' object
    if (teacher['homeroom_class'] != null) {
      if (teacher['homeroom_class'] is Map) {
        return 'Ya, Kelas ${teacher['homeroom_class']['name']}';
      }
    }

    return '-';
  }
}
