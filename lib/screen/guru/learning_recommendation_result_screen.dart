import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/screen/guru/learning_recommendation_edit_screen.dart';
import 'package:manajemensekolah/services/api_recommendation_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class LearningRecommendationResultScreen extends StatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> student;
  final Map<String, dynamic> classData;

  const LearningRecommendationResultScreen({
    super.key,
    required this.teacher,
    required this.student,
    required this.classData,
  });

  @override
  State<LearningRecommendationResultScreen> createState() =>
      _LearningRecommendationResultScreenState();
}

class _LearningRecommendationResultScreenState
    extends State<LearningRecommendationResultScreen> {
  bool _isLoading = true;
  List<dynamic> _recommendations = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiRecommendationService.getRecommendations(
        studentId: widget.student['id'].toString(),
      );

      if (response['success'] == true) {
        setState(() {
          _recommendations = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Gagal mengambil rekomendasi.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningRecommendationEditScreen(
          teacher: widget.teacher,
          student: widget.student,
          recommendations: _recommendations,
        ),
      ),
    );

    if (result == true) {
      _fetchRecommendations(); // Refresh if data was saved
    }
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
                        'Rekomendasi Belajar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Siswa: ${widget.student['nama'] ?? widget.student['name'] ?? 'Siswa'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading && _recommendations.isNotEmpty)
                  GestureDetector(
                    onTap: _navigateToEdit,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const SkeletonListLoading()
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _recommendations.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada rekomendasi untuk siswa ini saat ini.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final rec = _recommendations[index];
                      return _buildRecommendationCard(rec);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !_isLoading && _recommendations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToEdit,
              backgroundColor: _getPrimaryColor(),
              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
              label: const Text(
                'Edit Hasil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
    final type = rec['type']?.toString().toLowerCase() ?? 'other';

    Color priorityColor;
    if (priority == 'high') {
      priorityColor = Colors.red;
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Badge
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.more_horiz, color: ColorUtils.slate300),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              rec['title'] ?? 'Rekomendasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Description (HTML render)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REKOMENDASI:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                HtmlWidget(
                  rec['description'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 15,
                    color: ColorUtils.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // AI Reasoning
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorUtils.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ColorUtils.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: ColorUtils.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BERDASARKAN ANALISIS AI:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rec['ai_reasoning'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Materials
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: 12,
              ),
              child: Text(
                'MATERI & AKTIVITAS:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...(rec['materials'] as List).map((mat) => _buildMaterialItem(mat)),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(Map<String, dynamic> mat) {
    IconData iconData;
    Color iconColor;

    final type = mat['type']?.toString().toLowerCase() ?? 'other';
    if (type == 'video') {
      iconData = Icons.play_circle_filled_rounded;
      iconColor = Colors.red.shade600;
    } else if (type == 'exercise') {
      iconData = Icons.task_alt_rounded;
      iconColor = Colors.orange.shade700;
    } else if (type == 'reading') {
      iconData = Icons.auto_stories_rounded;
      iconColor = Colors.blue.shade700;
    } else {
      iconData = Icons.extension_rounded;
      iconColor = ColorUtils.slate400;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['title'] ?? 'Materi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: 8),
                HtmlWidget(
                  mat['content'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
