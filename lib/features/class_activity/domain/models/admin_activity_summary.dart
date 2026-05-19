// PODO models for the admin Kegiatan Kelas hub.
//
// Wraps the JSON shape returned by
// `GET /class-activities/admin-summary` so the screen has typed
// accessors instead of digging into Map<String, dynamic> everywhere.
//
// Mapped from the backend (AK.1):
//   * data[]             → AdminActivitySummary
//   * data[].submissions_summary → AdminActivitySubmissionSummary
//   * kpi                → AdminActivityKpi
//
// All fields are nullable when the underlying DB column allows null so
// the parser never throws on missing keys; defaults sit in the
// formatter / UI layer (e.g. "—" for null deadline).
library;

/// Type tag used by the hub's pill / type-tab filter.
///
/// Backend stores the column as a lowercase string. We accept the
/// common aliases the legacy code shipped before the type column was
/// formalized so existing rows keep mapping cleanly.
enum AdminActivityType {
  tugas,
  pr,
  ulangan,
  lainnya;

  static AdminActivityType fromRaw(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.isEmpty) return AdminActivityType.lainnya;
    if (v == 'tugas' || v == 'assignment') return AdminActivityType.tugas;
    if (v == 'pr' || v == 'homework') return AdminActivityType.pr;
    if (v == 'ulangan' || v == 'exam' || v == 'ujian' || v == 'kuis' ||
        v == 'quiz') {
      return AdminActivityType.ulangan;
    }
    return AdminActivityType.lainnya;
  }

  String get apiValue => switch (this) {
    AdminActivityType.tugas => 'tugas',
    AdminActivityType.pr => 'pr',
    AdminActivityType.ulangan => 'ulangan',
    AdminActivityType.lainnya => 'lainnya',
  };

  String get labelId => switch (this) {
    AdminActivityType.tugas => 'Tugas',
    AdminActivityType.pr => 'PR',
    AdminActivityType.ulangan => 'Ulangan',
    AdminActivityType.lainnya => 'Lainnya',
  };
}

/// Period shortcut used by the hub's filter chips.
enum AdminActivityPeriod {
  today,
  sevenDays,
  thirtyDays,
  semester,
  year;

  static AdminActivityPeriod fromRaw(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'today':
        return AdminActivityPeriod.today;
      case '7d':
      case '7days':
      case 'week':
        return AdminActivityPeriod.sevenDays;
      case '30d':
      case '30days':
      case 'month':
        return AdminActivityPeriod.thirtyDays;
      case 'semester':
        return AdminActivityPeriod.semester;
      case 'year':
      default:
        return AdminActivityPeriod.year;
    }
  }

  String get apiValue => switch (this) {
    AdminActivityPeriod.today => 'today',
    AdminActivityPeriod.sevenDays => '7d',
    AdminActivityPeriod.thirtyDays => '30d',
    AdminActivityPeriod.semester => 'semester',
    AdminActivityPeriod.year => 'year',
  };

  String get labelId => switch (this) {
    AdminActivityPeriod.today => 'Hari Ini',
    AdminActivityPeriod.sevenDays => '7 Hari',
    AdminActivityPeriod.thirtyDays => '30 Hari',
    AdminActivityPeriod.semester => 'Semester',
    AdminActivityPeriod.year => 'Tahun Ajaran',
  };
}

/// Per-activity submission progress block — drives the card's
/// "X / Y submit · Rerata 82.5" footer.
class AdminActivitySubmissionSummary {
  final int totalStudents;
  final int submitted;
  final int pending;
  final int late;
  final int excused;
  final double? avgScore;

  const AdminActivitySubmissionSummary({
    this.totalStudents = 0,
    this.submitted = 0,
    this.pending = 0,
    this.late = 0,
    this.excused = 0,
    this.avgScore,
  });

  factory AdminActivitySubmissionSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdminActivitySubmissionSummary();
    int asInt(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    return AdminActivitySubmissionSummary(
      totalStudents: asInt(json['total_students']),
      submitted: asInt(json['submitted']),
      pending: asInt(json['pending']),
      late: asInt(json['late']),
      excused: asInt(json['excused']),
      avgScore: asDouble(json['avg_score']),
    );
  }

  /// Whether this activity has any tracked submissions (vs being a
  /// material-only entry like an announcement). When false, the
  /// card hides the progress bar.
  bool get hasTracking =>
      totalStudents > 0 ||
      submitted > 0 ||
      pending > 0 ||
      late > 0 ||
      excused > 0;

  /// 0..1 ratio for the progress bar. Falls back to 0 when there are
  /// no enrolled students (so the bar stays at zero rather than NaN).
  double get progress {
    if (totalStudents == 0) return 0;
    return ((submitted + late) / totalStudents).clamp(0.0, 1.0);
  }
}

/// Top-level activity row rendered on the hub.
class AdminActivitySummary {
  final String id;
  final String? title;
  final String? description;
  final AdminActivityType type;
  final String? rawType;
  final DateTime? date;
  final String? time; // 'HH:MM'
  final String? targetRole;
  final String? classId;
  final String? className;
  final String? gradeLevel;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final AdminActivitySubmissionSummary submissions;

  const AdminActivitySummary({
    required this.id,
    this.title,
    this.description,
    this.type = AdminActivityType.lainnya,
    this.rawType,
    this.date,
    this.time,
    this.targetRole,
    this.classId,
    this.className,
    this.gradeLevel,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    this.submissions = const AdminActivitySubmissionSummary(),
  });

  factory AdminActivitySummary.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'];
    DateTime? date;
    if (dateRaw is String && dateRaw.isNotEmpty) {
      date = DateTime.tryParse(dateRaw);
    }
    return AdminActivitySummary(
      id: (json['id'] ?? '').toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      type: AdminActivityType.fromRaw(json['type']?.toString()),
      rawType: json['type']?.toString(),
      date: date,
      time: json['time']?.toString(),
      targetRole: json['target_role']?.toString(),
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      teacherName: json['teacher_name']?.toString(),
      submissions: AdminActivitySubmissionSummary.fromJson(
        json['submissions_summary'] is Map<String, dynamic>
            ? json['submissions_summary'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}

/// KPI strip values shown above the activity list.
class AdminActivityKpi {
  final int total;
  final int thisWeek;
  final int pendingSubmissions;

  const AdminActivityKpi({
    this.total = 0,
    this.thisWeek = 0,
    this.pendingSubmissions = 0,
  });

  factory AdminActivityKpi.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdminActivityKpi();
    int asInt(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
    return AdminActivityKpi(
      total: asInt(json['total']),
      thisWeek: asInt(json['this_week']),
      pendingSubmissions: asInt(json['pending_submissions']),
    );
  }
}

/// Composite payload returned by the helper — what the screen
/// actually consumes.
class AdminActivitySummaryPage {
  final List<AdminActivitySummary> items;
  final AdminActivityKpi kpi;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNextPage;

  const AdminActivitySummaryPage({
    required this.items,
    required this.kpi,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.hasNextPage = false,
  });

  factory AdminActivitySummaryPage.fromJson(Map<String, dynamic> json) {
    final rawData = (json['data'] as List?) ?? const [];
    final items = rawData
        .whereType<Map>()
        .map((m) => AdminActivitySummary.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final kpi = AdminActivityKpi.fromJson(
      json['kpi'] is Map<String, dynamic>
          ? json['kpi'] as Map<String, dynamic>
          : null,
    );
    final pag = json['pagination'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};
    int asInt(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
    return AdminActivitySummaryPage(
      items: items,
      kpi: kpi,
      currentPage: asInt(pag['current_page']),
      totalPages: asInt(pag['total_pages']),
      totalItems: asInt(pag['total_items']),
      hasNextPage: pag['has_next_page'] == true,
    );
  }

  AdminActivitySummaryPage copyWithItems(List<AdminActivitySummary> next) {
    return AdminActivitySummaryPage(
      items: next,
      kpi: kpi,
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      hasNextPage: hasNextPage,
    );
  }
}
