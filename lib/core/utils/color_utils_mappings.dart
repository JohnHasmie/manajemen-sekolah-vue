part of 'color_utils.dart';

/// Color mapping methods and semantic color resolvers for ColorUtils.
/// This file contains methods that map domain values (status, grade, role,
/// subject, day) to appropriate colors using switch/case or dictionary
/// lookups.

extension ColorMappings on ColorUtils {
  /// Returns a color mapped to a day name or semester name.
  /// Supports both Indonesian ("Senin") and English ("Monday") day
  /// names, plus semester names ("Ganjil"/"Genap"). Falls back to a
  /// hash-based color for unknown strings.
  ///
  /// [day] - Day name or semester name string.
  /// Returns the mapped [Color], or a deterministic fallback color.
  static Color getDayColor(String day) {
    // Support both Indonesian and English day names
    final Map<String, Color> dayColorMap = {
      // Indonesian days
      'Senin': const Color(0xFF6366F1),
      'Selasa': const Color(0xFF10B981),
      'Rabu': const Color(0xFFF59E0B),
      'Kamis': const Color(0xFFEF4444),
      'Jumat': const Color(0xFF8B5CF6),
      'Sabtu': const Color(0xFF06B6D4),

      // English days
      'Monday': const Color(0xFF6366F1),
      'Tuesday': const Color(0xFF10B981),
      'Wednesday': const Color(0xFFF59E0B),
      'Thursday': const Color(0xFFEF4444),
      'Friday': const Color(0xFF8B5CF6),
      'Saturday': const Color(0xFF06B6D4),

      // Semester names
      'Ganjil': const Color(0xFF6366F1),
      'Genap': const Color(0xFF10B981),
      'Odd': const Color(0xFF6366F1),
      'Even': const Color(0xFF10B981),
    };

    return dayColorMap[day] ?? _getFallbackColor(day);
  }

  /// Returns a semantic color for a given status string.
  /// Supports both Indonesian and English status labels.
  /// Green for positive (active/present), red for negative
  /// (absent/inactive), amber for warnings (late/pending), gray for
  /// unknown.
  ///
  /// [status] - Case-insensitive status string.
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'aktif':
      case 'present':
      case 'hadir':
      case 'completed':
      case 'selesai':
        return const Color(0xFF10B981);

      case 'inactive':
      case 'nonaktif':
      case 'absent':
      case 'absen':
      case 'pending':
      case 'menunggu':
        return const Color(0xFFEF4444);

      case 'warning':
      case 'peringatan':
      case 'late':
      case 'terlambat':
        return const Color(0xFFF59E0B);

      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Returns a color representing academic performance based on a
  /// numeric grade. Green (>=85), lime (>=75), amber (>=65), orange
  /// (>=55), red (<55).
  ///
  /// [grade] - Numeric score on a 0-100 scale.
  static Color getGradeColor(double grade) {
    if (grade >= 85) return const Color(0xFF10B981); // Excellent
    if (grade >= 75) return const Color(0xFF84CC16); // Good
    if (grade >= 65) return const Color(0xFFF59E0B); // Average
    if (grade >= 55) return const Color(0xFFFB923C); // Below Average
    return const Color(0xFFEF4444); // Poor
  }

  /// Returns a color associated with a user role.
  ///
  /// Aligned with the Kamil Edu brand palette (see
  /// `Kamil Edu - Brand Colour Guide.pdf`):
  ///   • Dark Blue   `#143068` — admin (authority)
  ///   • Cobalt Blue `#1B6FB8` — teacher (HSL midpoint of the two brand
  ///                              colors; bridges admin & parent visually,
  ///                              mirroring the role's "manage data + face
  ///                              students/parents" job)
  ///   • Azzure Blue `#21AFE6` — parent (friendly, end-user)
  ///
  /// Supports both Indonesian ("guru", "wali", "siswa") and English
  /// role names. Like mapping Laravel Spatie roles to badge colors.
  ///
  /// [role] - Case-insensitive role string.
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF143068); // Brand Dark Blue
      case 'guru':
      case 'teacher':
        return const Color(0xFF1B6FB8); // Brand Cobalt (midpoint)
      case 'staff':
        return const Color(0xFFFF9F1C); // Orange
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return const Color(0xFF21AFE6); // Brand Azzure Blue
      case 'siswa':
      case 'student':
        return const Color(0xFF21AFE6); // Brand Azzure Blue (same family)
      default:
        return const Color.fromARGB(255, 17, 19, 29);
    }
  }

  /// Returns a color for a school subject based on keyword matching.
  /// Searches the subject name for known keywords (e.g.,
  /// "matematika", "fisika") and returns the associated color. Falls
  /// back to hash-based color.
  ///
  /// [subjectName] - The subject/course name to color-code.
  static Color getSubjectColor(String subjectName) {
    final Map<String, Color> subjectColors = {
      // Languages
      'bahasa': const Color(0xFFEF4444),
      'indonesia': const Color(0xFFEF4444),
      'inggris': const Color(0xFF3B82F6),
      'english': const Color(0xFF3B82F6),
      'language': const Color(0xFFEF4444),

      // Sciences
      'matematika': const Color(0xFF6366F1),
      'mathematics': const Color(0xFF6366F1),
      'fisika': const Color(0xFF8B5CF6),
      'physics': const Color(0xFF8B5CF6),
      'kimia': const Color(0xFFEC4899),
      'chemistry': const Color(0xFFEC4899),
      'biologi': const Color(0xFF10B981),
      'biology': const Color(0xFF10B981),

      // Social Sciences
      'sejarah': const Color(0xFFF59E0B),
      'history': const Color(0xFFF59E0B),
      'geografi': const Color(0xFF84CC16),
      'geography': const Color(0xFF84CC16),
      'ekonomi': const Color(0xFF06B6D4),
      'economy': const Color(0xFF06B6D4),

      // Others
      'seni': const Color(0xFFEC4899),
      'art': const Color(0xFFEC4899),
      'olahraga': const Color(0xFF84CC16),
      'sport': const Color(0xFF84CC16),
      'komputer': const Color(0xFF6366F1),
      'computer': const Color(0xFF6366F1),
    };

    final lowerSubject = subjectName.toLowerCase();

    for (final key in subjectColors.keys) {
      if (lowerSubject.contains(key)) {
        return subjectColors[key]!;
      }
    }

    return _getFallbackColor(subjectName);
  }

  /// Returns a two-color gradient pair for card backgrounds based on
  /// a semantic type. Types: 'primary', 'success', 'warning',
  /// 'danger', 'info'.
  ///
  /// [type] - Case-insensitive semantic type string.
  /// Returns a `List<Color>` with [start, end] gradient colors.
  static List<Color> getCardGradient(String type) {
    switch (type.toLowerCase()) {
      case 'primary':
        return [const Color(0xFF4F46E5), const Color(0xFF7C73FA)];
      case 'success':
        return [const Color(0xFF10B981), const Color(0xFF34D399)];
      case 'warning':
        return [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
      case 'danger':
        return [const Color(0xFFEF4444), const Color(0xFFF87171)];
      case 'info':
        return [const Color(0xFF06B6D4), const Color(0xFF67E8F9)];
      default:
        return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    }
  }

  /// Generates a deterministic color from a string's hash code.
  /// Ensures the same text always gets the same color across app
  /// restarts. Like a simple hash function - converts text to a
  /// palette index.
  static Color _getFallbackColor(String text) {
    // Generate consistent color based on text hash
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFEC4899),
      const Color(0xFF84CC16),
    ];

    return colors[hash.abs() % colors.length];
  }

  /// Helper to adjust color brightness for gradients
  static Color _adjustColor(Color color, double factor) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    final a = (color.a * 255.0).round();

    return Color.fromARGB(
      a,
      (r + (255 - r) * factor).round().clamp(0, 255),
      (g + (255 - g) * factor).round().clamp(0, 255),
      (b + (255 - b) * (factor * 1.5)).round().clamp(0, 255),
    );
  }
}
