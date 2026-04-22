import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Mixin for report card grade tab filtering and scroll logic.
mixin GradeTabFilteringMixin {
  late ScrollController scrollController;
  late Map<int, GlobalKey> subjectKeys;
  int? activeFilterIndex;

  /// Handle chip tap for filtering subjects by index.
  void onChipTap(int index, void Function(void Function()) setStateCallback) {
    setStateCallback(() {
      if (activeFilterIndex == index) {
        activeFilterIndex = null;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => scrollToSubject(index),
        );
      } else {
        activeFilterIndex = index;
      }
    });
  }

  /// Scroll to a subject by its index using the global key.
  void scrollToSubject(int index) {
    final key = subjectKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  /// Get the list of visible indices based on active filter.
  List<int> getVisibleIndices(int totalSubjects) {
    if (activeFilterIndex != null && activeFilterIndex! < totalSubjects) {
      return [activeFilterIndex!];
    } else {
      return List.generate(totalSubjects, (i) => i);
    }
  }
}
