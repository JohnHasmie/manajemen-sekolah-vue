import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_card.dart';

class TeacherListContent extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> teachers;
  final bool isLoadingMore;
  final bool hasSearch;
  final bool hasFilter;
  final ScrollController scrollController;
  final LanguageProvider languageProvider;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final bool hasMoreData;
  final Function(Map<String, dynamic>) onTapDetail;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  const TeacherListContent({
    super.key,
    required this.isLoading,
    required this.teachers,
    required this.isLoadingMore,
    required this.hasSearch,
    required this.hasFilter,
    required this.scrollController,
    required this.languageProvider,
    required this.onRefresh,
    required this.onLoadMore,
    required this.hasMoreData,
    required this.onTapDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<Map<String, dynamic>>(
      items: teachers.cast<Map<String, dynamic>>(),
      itemBuilder: (context, teacher, index) {
        return TeacherCard(
          teacher: teacher,
          index: index,
          onTap: () => onTapDetail(teacher),
          onEdit: () => onEdit(teacher),
          onDelete: () => onDelete(teacher),
        );
      },
      onLoadMore: onLoadMore,
      hasMore: hasMoreData,
      isLoadingMore: isLoadingMore,
      isInitialLoading: isLoading && teachers.isEmpty,
      loadingState: const SkeletonListLoading(itemCount: 6, infoTagCount: 2),
      emptyState: EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No teachers',
          'id': 'Tidak ada guru',
        }),
        subtitle: !hasSearch && !hasFilter
            ? languageProvider.getTranslatedText({
                'en': 'Tap + to add a teacher',
                'id': 'Tap + untuk menambah guru',
              })
            : languageProvider.getTranslatedText({
                'en': 'No search results found',
                'id': 'Tidak ditemukan hasil pencarian',
              }),
        icon: Icons.person_outline,
      ),
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      onRefresh: onRefresh,
    );
  }
}
