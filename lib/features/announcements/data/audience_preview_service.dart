// Wrapper around POST /api/announcements/preview-reach (Mockup #10).
// Returns the live audience caption that the AudienceSummaryStrip
// renders in the compose sheet.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_announcement_components.dart';

class AudiencePreview {
  final int total;
  final String caption;
  const AudiencePreview({required this.total, required this.caption});

  bool get hasAudience => total > 0;
}

class AudiencePreviewService {
  final ApiService _api;
  AudiencePreviewService(this._api);

  /// POST /api/announcements/preview-reach
  ///
  /// Sends the matrix payload as JSON and returns the parsed caption.
  Future<AudiencePreview> fetch(AudienceMatrixSelection selection) async {
    if (selection.isEmpty) {
      return const AudiencePreview(
        total: 0,
        caption: 'Pilih minimal 1 audiens',
      );
    }

    final payload = {'audience_matrix': selection.toApiPayload()};
    final raw = await _api.post('/announcements/preview-reach', payload);
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};
    return AudiencePreview(
      total: (data['total'] as num?)?.toInt() ?? 0,
      caption: (data['caption'] ?? '').toString(),
    );
  }
}

final audiencePreviewServiceProvider =
    Provider<AudiencePreviewService>((ref) {
  return AudiencePreviewService(ApiService());
});
