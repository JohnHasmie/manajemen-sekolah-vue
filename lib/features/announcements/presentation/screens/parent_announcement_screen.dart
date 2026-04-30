// School announcements screen for parents (wali murid).
// Like `pages/parent/Announcements.vue` in a Vue app.
//
// Displays a list of school announcements with read/unread tracking.
// Automatically marks announcements as read when visible (debounced
// visibility pattern). Supports search, file attachments, detail view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_card_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/content_state_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/file_operations_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/formatting_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/header_search_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/read_tracking_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/tour_logic_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/ui_interaction_mixin.dart';

/// School announcements list with automatic read tracking.
class ParentAnnouncementScreen extends ConsumerStatefulWidget {
  const ParentAnnouncementScreen({super.key});

  @override
  ParentAnnouncementScreenState createState() =>
      ParentAnnouncementScreenState();
}

/// State for [ParentAnnouncementScreen].
class ParentAnnouncementScreenState
    extends ConsumerState<ParentAnnouncementScreen>
    with
        ReadTrackingMixin,
        FileOperationsMixin,
        DataLoadingMixin,
        FormattingMixin,
        TourLogicMixin,
        AnnouncementCardMixin,
        HeaderSearchMixin,
        ContentStateMixin,
        UiInteractionMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    markReadDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  GlobalKey? get searchKey => _searchKey;

  @override
  GlobalKey? get listKey => _listKey;

  @override
  TextEditingController get searchController => _searchController;

  @override
  List<dynamic> get filteredAnnouncement => getFilteredAnnouncement();

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await popWithFlush(context);
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: BrandPageLayout(
          header: buildHeader(languageProvider),
          role: 'wali',
          onRefresh: forceRefresh,
          bodyChildren: [
            buildContent(languageProvider),
          ],
        ),
      ),
    );
  }
}
