import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_edit_screen.dart';

/// Mixin for controller management in recommendation edit screen.
///
/// Handles initialization, conversion, and disposal of text and Quill
/// controllers for editing recommendation titles and content.
mixin EditControllerMixin on State<LearningRecommendationEditScreen> {
  /// Map of title controllers, keyed by recommendation ID.
  Map<String, TextEditingController> get titleControllers;

  /// Map of description Quill controllers, keyed by recommendation ID.
  Map<String, quill.QuillController> get descriptionControllers;

  /// Map of material Quill controllers, keyed by [recId][matId].
  Map<String, Map<String, quill.QuillController>> get materialControllers;

  /// Map of priorities, keyed by recommendation ID.
  Map<String, String> get priorities;

  /// Gets widget recommendations list.
  List<dynamic> get widgetRecommendations;

  /// Initializes all controllers from recommendation data.
  ///
  /// Creates TextEditingController for titles, QuillController for
  /// descriptions and materials, and maps priorities for each recommendation.
  void initControllers() {
    for (final rec in widgetRecommendations) {
      final recId = rec['id']?.toString() ?? UniqueKey().toString();

      // Title
      titleControllers[recId] = TextEditingController(text: rec['title'] ?? '');

      // Priority
      priorities[recId] = rec['priority']?.toString().toLowerCase() ?? 'low';

      // Description
      descriptionControllers[recId] = quill.QuillController(
        document: convertHtmlToQuill(rec['description'] ?? ''),
        selection: const TextSelection.collapsed(offset: 0),
      );

      if (rec['materials'] != null) {
        materialControllers[recId] = {};
        for (final mat in rec['materials']) {
          final matId = mat['id']?.toString() ?? UniqueKey().toString();
          materialControllers[recId]?[matId] = quill.QuillController(
            document: convertHtmlToQuill(mat['content'] ?? ''),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      }
    }
  }

  /// Converts HTML string to Quill Document format.
  ///
  /// Parses HTML tags and converts them to plain text with formatting hints.
  /// Handles lists, headings, paragraphs, and HTML entities.
  quill.Document convertHtmlToQuill(String html) {
    if (html.isEmpty) return quill.Document();

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
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    return quill.Document()..insert(0, text);
  }

  /// Disposes all controllers and frees resources.
  ///
  /// Cleans up TextEditingControllers and QuillControllers before
  /// screen disposal.
  void disposeAllControllers() {
    for (final controller in titleControllers.values) {
      controller.dispose();
    }
    for (final controller in descriptionControllers.values) {
      controller.dispose();
    }
    for (final materialGroup in materialControllers.values) {
      for (final controller in materialGroup.values) {
        controller.dispose();
      }
    }
  }
}
