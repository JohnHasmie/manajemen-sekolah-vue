import 'package:flutter/material.dart';

class ColorUtils {
  static Color getColorForIndex(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  static Color get primaryColor => Color(0xFF4F46E5);

  static Color getDayColor(String day) {
    // Support both Indonesian and English day names
    final Map<String, Color> dayColorMap = {
      // Indonesian days
      'Senin': Color(0xFF6366F1),
      'Selasa': Color(0xFF10B981),
      'Rabu': Color(0xFFF59E0B),
      'Kamis': Color(0xFFEF4444),
      'Jumat': Color(0xFF8B5CF6),
      'Sabtu': Color(0xFF06B6D4),

      // English days
      'Monday': Color(0xFF6366F1),
      'Tuesday': Color(0xFF10B981),
      'Wednesday': Color(0xFFF59E0B),
      'Thursday': Color(0xFFEF4444),
      'Friday': Color(0xFF8B5CF6),
      'Saturday': Color(0xFF06B6D4),

      // Semester names
      'Ganjil': Color(0xFF6366F1),
      'Genap': Color(0xFF10B981),
      'Odd': Color(0xFF6366F1),
      'Even': Color(0xFF10B981),
    };

    return dayColorMap[day] ?? _getFallbackColor(day);
  }

  static Color _getFallbackColor(String text) {
    // Generate consistent color based on text hash
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
      Color(0xFF84CC16),
    ];

    return colors[hash.abs() % colors.length];
  }

  // Get color for status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'aktif':
      case 'present':
      case 'hadir':
      case 'completed':
      case 'selesai':
        return Color(0xFF10B981);

      case 'inactive':
      case 'nonaktif':
      case 'absent':
      case 'absen':
      case 'pending':
      case 'menunggu':
        return Color(0xFFEF4444);

      case 'warning':
      case 'peringatan':
      case 'late':
      case 'terlambat':
        return Color(0xFFF59E0B);

      default:
        return Color(0xFF6B7280);
    }
  }

  // Get color for grade
  static Color getGradeColor(double grade) {
    if (grade >= 85) return Color(0xFF10B981); // Excellent
    if (grade >= 75) return Color(0xFF84CC16); // Good
    if (grade >= 65) return Color(0xFFF59E0B); // Average
    if (grade >= 55) return Color(0xFFFB923C); // Below Average
    return Color(0xFFEF4444); // Poor
  }

  // Get color for role
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Color(0xFF2563EB); // Blue
      case 'guru':
      case 'teacher':
        return Color(0xFF16A34A); // Green
      case 'staff':
        return Color(0xFFFF9F1C); // Orange
      case 'wali':
      case 'parent':
      case 'orang_tua':
        return Color(0xFF9333EA); // Purple
      case 'siswa':
      case 'student':
        return Color(0xFF3B82F6); // Blue
      default:
        return Color.fromARGB(255, 17, 19, 29);
    }
  }

  // Get color for subject category
  static Color getSubjectColor(String subjectName) {
    final Map<String, Color> subjectColors = {
      // Languages
      'bahasa': Color(0xFFEF4444),
      'indonesia': Color(0xFFEF4444),
      'inggris': Color(0xFF3B82F6),
      'english': Color(0xFF3B82F6),
      'language': Color(0xFFEF4444),

      // Sciences
      'matematika': Color(0xFF6366F1),
      'mathematics': Color(0xFF6366F1),
      'fisika': Color(0xFF8B5CF6),
      'physics': Color(0xFF8B5CF6),
      'kimia': Color(0xFFEC4899),
      'chemistry': Color(0xFFEC4899),
      'biologi': Color(0xFF10B981),
      'biology': Color(0xFF10B981),

      // Social Sciences
      'sejarah': Color(0xFFF59E0B),
      'history': Color(0xFFF59E0B),
      'geografi': Color(0xFF84CC16),
      'geography': Color(0xFF84CC16),
      'ekonomi': Color(0xFF06B6D4),
      'economy': Color(0xFF06B6D4),

      // Others
      'seni': Color(0xFFEC4899),
      'art': Color(0xFFEC4899),
      'olahraga': Color(0xFF84CC16),
      'sport': Color(0xFF84CC16),
      'komputer': Color(0xFF6366F1),
      'computer': Color(0xFF6366F1),
    };

    final lowerSubject = subjectName.toLowerCase();

    for (var key in subjectColors.keys) {
      if (lowerSubject.contains(key)) {
        return subjectColors[key]!;
      }
    }

    return _getFallbackColor(subjectName);
  }

  // Get gradient for cards
  static List<Color> getCardGradient(String type) {
    switch (type.toLowerCase()) {
      case 'primary':
        return [Color(0xFF4F46E5), Color(0xFF7C73FA)];
      case 'success':
        return [Color(0xFF10B981), Color(0xFF34D399)];
      case 'warning':
        return [Color(0xFFF59E0B), Color(0xFFFBBF24)];
      case 'danger':
        return [Color(0xFFEF4444), Color(0xFFF87171)];
      case 'info':
        return [Color(0xFF06B6D4), Color(0xFF67E8F9)];
      default:
        return [Color(0xFF6B7280), Color(0xFF9CA3AF)];
    }
  }

  // Get text color based on background color
  static Color getTextColorForBackground(Color backgroundColor) {
    // Calculate the perceptive luminance
    final luminance =
        (0.299 * backgroundColor.red +
            0.587 * backgroundColor.green +
            0.114 * backgroundColor.blue) /
        255;

    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Get shimmer base colors
  static Color get shimmerBaseColor => Colors.grey[300]!;
  static Color get shimmerHighlightColor => Colors.grey[100]!;

  // Get border color
  static Color get borderColor => Colors.grey[300]!;

  // Get divider color
  static Color get dividerColor => Colors.grey[200]!;

  // Get shadow color
  static Color get shadowColor => Colors.black.withOpacity(0.1);

  // Get disabled color
  static Color get disabledColor => Colors.grey[400]!;

  // Get success color variants
  static Color get successLight => Color(0xFFD1FAE5);
  static Color get successDark => Color(0xFF065F46);

  // Get warning color variants
  static Color get warningLight => Color(0xFFFEF3C7);
  static Color get warningDark => Color(0xFF92400E);

  // Get error color variants
  static Color get errorLight => Color(0xFFFEE2E2);
  static Color get errorDark => Color(0xFF991B1B);

  // Get info color variants
  static Color get infoLight => Color(0xFFE0F2FE);
  static Color get infoDark => Color(0xFF0C4A6E);

  // Slate Colors
  static Color get slate50 => Color(0xFFF8FAFC);
  static Color get slate100 => Color(0xFFF1F5F9);
  static Color get slate200 => Color(0xFFE2E8F0);
  static Color get slate300 => Color(0xFFCBD5E1);
  static Color get slate400 => Color(0xFF94A3B8);
  static Color get slate500 => Color(0xFF64748B);
  static Color get slate600 => Color(0xFF475569);
  static Color get slate700 => Color(0xFF334155);
  static Color get slate800 => Color(0xFF1E293B);
  static Color get slate900 => Color(0xFF0F172A);
  static Color get slate950 => Color(0xFF020617);

  // Primary Alias
  static Color get primary => primaryColor;

  // Corporate Blue Colors (Professional & Conservative)
  static Color get corporateBlue900 => Color(0xFF1E3A8A); // Dark headings
  static Color get corporateBlue800 => Color(0xFF1E40AF);
  static Color get corporateBlue700 => Color(0xFF1D4ED8); // Primary actions
  static Color get corporateBlue600 => Color(0xFF2563EB);
  static Color get corporateBlue500 => Color(0xFF3B82F6); // Interactive elements
  static Color get corporateBlue400 => Color(0xFF60A5FA);
  static Color get corporateBlue300 => Color(0xFF93C5FD);
  static Color get corporateBlue200 => Color(0xFFBFDBFE);
  static Color get corporateBlue100 => Color(0xFFDBEAFE); // Light backgrounds
  static Color get corporateBlue50 => Color(0xFFEFF6FF);

  // Semantic Colors for Dashboard
  static Color get success600 => Color(0xFF059669);
  static Color get warning600 => Color(0xFFD97706);
  static Color get error600 => Color(0xFFDC2626);
  static Color get info600 => Color(0xFF0891B2);

  /// Professional card decoration for corporate dashboard
  static BoxDecoration corporateCard({
    Color? accentColor,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12), // Sharper than default 16
      border: withBorder
          ? Border.all(
              color: slate200,
              width: 1,
            )
          : null,
      boxShadow: corporateShadow(),
    );
  }

  /// Layered shadow for professional depth
  static List<BoxShadow> corporateShadow({double elevation = 1.0}) {
    return [
      BoxShadow(
        color: slate900.withOpacity(0.04 * elevation),
        blurRadius: 6 * elevation,
        offset: Offset(0, 2 * elevation),
      ),
      BoxShadow(
        color: slate900.withOpacity(0.02 * elevation),
        blurRadius: 12 * elevation,
        offset: Offset(0, 4 * elevation),
      ),
    ];
  }

  /// Subtle gradient for cards
  static LinearGradient corporateGradient({
    required Color color,
    double opacity = 0.1,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withOpacity(opacity),
        color.withOpacity(opacity * 0.5),
      ],
    );
  }

  /// Professional stat card decoration
  static BoxDecoration statCardDecoration({required Color accentColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: slate200,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: accentColor.withOpacity(0.08),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: slate900.withOpacity(0.04),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  /// Category header decoration
  static BoxDecoration categoryHeaderDecoration({
    required Color accentColor,
    bool isExpanded = true,
  }) {
    return BoxDecoration(
      color: accentColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: accentColor.withOpacity(0.2),
        width: 1,
      ),
    );
  }

  /// Modern hero gradient
  // Kamil Edu Professional Colors
  static Color get kamilPrimary => Color(0xFF143068); // Deep professional blue
  static Color get kamilAccent => Color(0xFF21AFE6); // Vibrant teal
  static Color get kamilPrimaryLight => Color(0xFFE8EEF7);
  static Color get kamilAccentLight => Color(0xFFE6F7FD);

  /// Modern hero gradient with vibrant colors
  static LinearGradient heroGradient({required Color primaryColor}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        _adjustColor(primaryColor, 0.15), // Slightly lighter mid-tone
        _adjustColor(primaryColor, 0.35), // Vibrant accent mix
      ],
      stops: [0.0, 0.5, 1.4],
    );
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

  /// Glass morphism effect
  static BoxDecoration glassMorphism({
    Color? color,
    double blur = 10,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: blur,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  /// Quick action button decoration
  static BoxDecoration quickActionDecoration({required Color color}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: slate200, width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}
