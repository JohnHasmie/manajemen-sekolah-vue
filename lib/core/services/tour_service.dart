/// api_tour_services.dart - Manages onboarding tour/walkthrough state.
/// Like Laravel's TourController / Vue's tour store module.
///
/// Tracks whether a user has seen the onboarding tour for their role,
/// saves progress (last step reached), and marks tours as completed.
/// Tours are platform-specific (mobile vs web) and role-specific.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';

/// Service for onboarding tour API calls.
/// Like a small Laravel controller with status/complete/save-progress actions.
/// In Vue terms, this is a simple store module for managing first-time user guidance.
class ApiTourService {
  /// Check if the authenticated user should see the tour.
  Future<Map<String, dynamic>> getTourStatus({
    required String platform,
    required String role,
    required String name,
  }) async {
    final response = await dioClient.get(
      '/tours/status',
      queryParameters: {
        'platform': platform,
        'role': role,
        'name': name,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Mark tour as completed.
  Future<Map<String, dynamic>> completeTour({
    required String tourId,
    required String platform,
  }) async {
    final response = await dioClient.post(
      '/tours/complete',
      data: {'tour_id': tourId, 'platform': platform},
    );

    return response.data as Map<String, dynamic>;
  }

  /// Save tour progress (last step reached).
  Future<Map<String, dynamic>> saveTourProgress({
    required String tourId,
    required String platform,
    required int lastStep,
  }) async {
    final response = await dioClient.post(
      '/tours/save-progress',
      data: {
        'tour_id': tourId,
        'platform': platform,
        'last_step': lastStep,
      },
    );

    return response.data as Map<String, dynamic>;
  }
}
