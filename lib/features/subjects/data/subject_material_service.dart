/// Material hierarchy management (Chapter > Sub-chapter > Content).
/// Handles curriculum structure CRUD operations.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';

/// Manages material hierarchy: chapters (bab), sub-chapters
/// (sub-bab), and content materials.
/// Like Laravel models: Chapter, SubChapter, ContentMaterial.
class SubjectMaterialService {
  /// Fetches content materials for a specific sub-chapter.
  /// Part of: Subject > Chapter > SubChapter > Content.
  Future<List<dynamic>> getContentMaterials({
    required String subChapterId,
  }) async {
    final response = await dioClient.get(
      '/content-material?sub_chapter_id=$subChapterId',
    );

    final result = response.data;
    if (result is List) return result;
    if (result is Map && result['data'] is List) {
      return result['data'];
    }
    return [];
  }

  /// Fetches chapters for a subject. Top level of material
  /// hierarchy.
  /// Like: Chapter::where('subject_id', $id)->get()
  Future<List<dynamic>> getChapterMaterials({
    String? subjectId,
    String? search,
  }) async {
    String url = '/bab-material?';
    if (subjectId != null) url += 'subject_id=$subjectId&';
    if (search != null && search.isNotEmpty) {
      url += 'search=${Uri.encodeComponent(search)}&';
    }

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches sub-chapters for a given chapter.
  /// Like: SubChapter::where('chapter_id', $chapterId)->get()
  Future<List<dynamic>> getSubChapterMaterials({
    required String chapterId,
  }) async {
    final response = await dioClient.get(
      '/sub-bab-material?chapter_id=$chapterId',
    );

    final result = response.data;
    return result is List ? result : [];
  }

  /// Creates a new chapter material.
  Future<dynamic> addChapterMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/bab-material', data: data);
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }

  /// Creates a new sub-chapter material.
  Future<dynamic> addSubChapterMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/sub-bab-material', data: data);
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }

  /// Creates new content material.
  Future<dynamic> addContentMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/content-material', data: data);
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }

  /// Updates a chapter material.
  Future<void> updateChapterMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/bab-material/$id', data: data);
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Updates a sub-chapter material.
  Future<void> updateSubChapterMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/sub-bab-material/$id', data: data);
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Updates content material.
  Future<void> updateContentMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/content-material/$id', data: data);
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Deletes a chapter material.
  Future<void> deleteChapterMaterial(String id) async {
    await dioClient.delete('/bab-material/$id');
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Deletes a sub-chapter material.
  Future<void> deleteSubChapterMaterial(String id) async {
    await dioClient.delete('/sub-bab-material/$id');
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Deletes content material.
  Future<void> deleteContentMaterial(String id) async {
    await dioClient.delete('/content-material/$id');
    await CacheInvalidationService.onMaterialChanged();
  }

  /// Fetches general materials (generic lesson materials).
  Future<List<dynamic>> getMaterials({
    String? teacherId,
    String? subjectId,
  }) async {
    String url = '/materials?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Adds a new material.
  Future<dynamic> addMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/materials', data: data);
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }
}
