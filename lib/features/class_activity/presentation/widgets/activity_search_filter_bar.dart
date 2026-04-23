// ActivitySearchFilterBar — search field + filter icon button.
// Matches the "Jadwal Mengajar" search bar style: 48px height, white bg,
// border-radius 12, filter button with badge dot.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ActivitySearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final GlobalKey searchFilterKey;
  final Color primaryColor;
  final bool hasActiveFilter;
  final LanguageProvider languageProvider;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilterPressed;

  const ActivitySearchFilterBar({
    super.key,
    required this.searchController,
    required this.searchFilterKey,
    required this.primaryColor,
    required this.hasActiveFilter,
    required this.languageProvider,
    required this.onSearchSubmitted,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        key: searchFilterKey,
        children: [
          // Search field — matching schedule screen style
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        color: ColorUtils.slate800,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: languageProvider.getTranslatedText({
                          'en': 'Search activities...',
                          'id': 'Cari kegiatan...',
                        }),
                        hintStyle: TextStyle(
                          color: ColorUtils.slate400,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      onSubmitted: (_) {
                        onSearchSubmitted();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.search, color: primaryColor, size: 20),
                      onPressed: () {
                        onSearchSubmitted();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Filter button with badge dot
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: hasActiveFilter
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveFilter ? primaryColor : ColorUtils.slate200,
                width: hasActiveFilter ? 1.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: onFilterPressed,
                  icon: Icon(
                    Icons.tune,
                    color: hasActiveFilter ? primaryColor : ColorUtils.slate600,
                    size: 20,
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
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ColorUtils.error600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
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
