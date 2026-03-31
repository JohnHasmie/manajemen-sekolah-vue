// Tour helper for the class-activity screen.
// Extracted from teacher_class_activity_screen.dart to reduce file size.
// Contains the target-focus definitions and the TutorialCoachMark invocation.
// Like a Vue mixin that encapsulates onboarding-tour logic.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Builds the list of [TargetFocus] steps for the class-activity onboarding tour.
///
/// Parameters mirror the GlobalKey fields and permission flag held in
/// [ClassActivityScreenState]. Keeping them as plain parameters (instead of
/// accessing state directly) means this file has no dependency on the State
/// class — like passing Vue props to a mixin method.
List<TargetFocus> buildClassActivityTourTargets({
  required GlobalKey tabSwitcherKey,
  required GlobalKey searchFilterKey,
  required GlobalKey fabKey,
  required bool selectedSubjectCanEdit,
}) {
  final List<TargetFocus> targets = [];

  targets.add(
    TargetFocus(
      identify: "TabSwitcher",
      keyTarget: tabSwitcherKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Mode Tampilan",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Pilih 'Semua Siswa' untuk melihat aktivitas umum kelas, atau 'Khusus Siswa' untuk melihat histori aktivitas per murid.",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  targets.add(
    TargetFocus(
      identify: "SearchFilter",
      keyTarget: searchFilterKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Pencarian & Filter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Cari aktivitas berdasarkan judul atau gunakan filter untuk mencari rentang waktu tertentu.",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  if (selectedSubjectCanEdit) {
    targets.add(
      TargetFocus(
        identify: "AddActivity",
        keyTarget: fabKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tambah Aktivitas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Gunakan tombol ini untuk menambahkan aktivitas absensi/jurnal kelas maupun memberikan penugasan (PR / Ujian) kepada siswa.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  return targets;
}

/// Launches the [TutorialCoachMark] for the class-activity screen.
///
/// Accepts pre-built [targets] so the caller can pass GlobalKey references
/// from its own State. On finish/skip it records tour completion via the
/// API and clears the local cache flag.
void showClassActivityTour({
  required BuildContext context,
  required List<TargetFocus> targets,
}) {
  if (targets.isEmpty) return;

  TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    textSkip: "LEWATI",
    paddingFocus: 10,
    opacityShadow: 0.8,
    onFinish: () {
      getIt<ApiTourService>().completeTour(
        name: 'class_activity_tour',
        role: 'guru',
        platform: 'mobile',
      );
      LocalCacheService.save(
        CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'),
        {'should_show': false},
      );
    },
    onSkip: () {
      getIt<ApiTourService>().completeTour(
        name: 'class_activity_tour',
        role: 'guru',
        platform: 'mobile',
      );
      LocalCacheService.save(
        CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'),
        {'should_show': false},
      );
      return true;
    },
  ).show(context: context);
}
