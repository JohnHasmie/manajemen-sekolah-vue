import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing UI helper methods for sub-chapter detail screen.
mixin SubChapterUiMixin on ConsumerState<SubBabDetailPage> {
  /// Strip HTML tags from text string.
  String stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (text.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n\n');
    return text.trim();
  }

  /// Get primary color for teacher role.
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');

  /// Get gradient for cards.
  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  /// Parse material content from AI data.
  Map<String, dynamic>? parseMaterialContent(Map<String, dynamic>? aiData) {
    final raw = aiData?['material_content'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final parsed = json.decode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  /// Check if empty content should be shown.
  bool shouldShowEmpty(
    List<dynamic> contentList,
    Map<String, dynamic>? aiData,
    bool isLoading,
    bool isLoadingAi,
    bool isPollingAi,
  ) {
    return (contentList.isEmpty &&
            aiData == null &&
            !isLoadingAi &&
            !isPollingAi) ||
        ((isLoadingAi || isPollingAi) && aiData == null);
  }
}
