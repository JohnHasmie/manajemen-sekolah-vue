import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:manajemensekolah/widgets/dashboard/menu_item_card.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'learning_recommendation_student_screen.dart';

class LearningRecommendationClassScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final List<dynamic> classes;

  const LearningRecommendationClassScreen({
    super.key,
    required this.teacher,
    required this.classes,
  });

  @override
  State<LearningRecommendationClassScreen> createState() =>
      _LearningRecommendationClassScreenState();
}

class _LearningRecommendationClassScreenState
    extends State<LearningRecommendationClassScreen> {
  final GlobalKey _classListKey = GlobalKey();
  String? _tourId;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _checkAndShowTour() async {
    try {
      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'learning_recommendation_class_tour',
      );

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];
        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

    targets.add(
      TargetFocus(
        identify: "ClassList",
        keyTarget: _classListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Class List',
                        'id': 'Daftar Kelas',
                      }),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en':
                              'Choose one of your classes to see student learning recommendations.',
                          'id':
                              'Pilih salah satu kelas Anda untuk melihat rekomendasi belajar siswa.',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Kelas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih kelas perwalian Anda untuk melihat rekomendasi belajaran siswa',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.classes.length,
              itemBuilder: (context, index) {
                final cls = widget.classes[index];
                return Padding(
                  key: index == 0 ? _classListKey : null,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MenuItemCard(
                    title: cls['name'] ?? cls['nama'] ?? 'Kelas Tanpa Nama',
                    icon: Icons.class_outlined,
                    primaryColor: _getPrimaryColor(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LearningRecommendationStudentScreen(
                                teacher: widget.teacher,
                                classData: cls,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
