import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

/// Mixin for UI helpers (colors, gradients, filtering).
mixin TeacherScheduleUiMixin on ConsumerState<TeachingScheduleScreen> {
  // Day-color identity for the schedule-card hour chip — Senin indigo,
  // Selasa emerald, Rabu amber, Kamis rose/red, Jumat teal, Sabtu
  // violet. Matches the day-of-week swatches in the
  // `_design/teacher_jadwal_redesign.html` legend so the visual story
  // stays in sync between mockup and shipped UI.
  final Map<String, Color> dayColorMapInternal = {
    'Senin': ColorUtils.indigo500,
    'Selasa': ColorUtils.emerald500,
    'Rabu': ColorUtils.amber500,
    'Kamis': ColorUtils.red500,
    'Jumat': ColorUtils.cyan500,
    'Sabtu': ColorUtils.violet500,
  };

  Color getPrimaryColor() {
    return ref.read(teacherScheduleControllerProvider).getPrimaryColor();
  }

  LinearGradient getCardGradient() {
    return ref.read(teacherScheduleControllerProvider).getCardGradient();
  }

  Map<String, Color> get dayColorMap => dayColorMapInternal;
}
