import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

/// Mixin for UI helpers (colors, gradients, filtering).
mixin TeacherScheduleUiMixin on ConsumerState<TeachingScheduleScreen> {
  final Map<String, Color> dayColorMapInternal = {
    'Senin': ColorUtils.indigo500,
    'Selasa': ColorUtils.emerald500,
    'Rabu': ColorUtils.amber500,
    'Kamis': ColorUtils.red500,
    'Jumat': ColorUtils.violet500,
    'Sabtu': ColorUtils.cyan500,
  };

  Color getPrimaryColor() {
    return ref.read(teacherScheduleControllerProvider).getPrimaryColor();
  }

  LinearGradient getCardGradient() {
    return ref.read(teacherScheduleControllerProvider).getCardGradient();
  }

  Map<String, Color> get dayColorMap => dayColorMapInternal;
}
