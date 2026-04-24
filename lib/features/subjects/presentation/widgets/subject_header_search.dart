import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Subject header search and filter widget.
class SubjectHeaderSearch extends ConsumerWidget {
  final GlobalKey searchKey;
  final TextEditingController searchController;
  final GlobalKey filterKey;
  final bool hasActiveFilter;
  final Color primaryColor;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const SubjectHeaderSearch({
    super.key,
    required this.searchKey,
    required this.searchController,
    required this.filterKey,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    return Row(
      children: [
        Expanded(
          child: Container(
            key: searchKey,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search subjects...',
                        'id': 'Cari mata pelajaran...',
                      }),
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      onSearch();
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: primaryColor),
                    onPressed: onSearch,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          key: filterKey,
          decoration: BoxDecoration(
            color: hasActiveFilter
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              IconButton(
                onPressed: onFilter,
                icon: Icon(
                  Icons.tune,
                  color: hasActiveFilter ? primaryColor : Colors.white,
                ),
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Filter',
                  'id': 'Filter',
                }),
              ),
              if (hasActiveFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
