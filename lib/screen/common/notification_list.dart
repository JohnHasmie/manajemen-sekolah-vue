import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/walimurid/announcement_screen.dart';
import 'package:manajemensekolah/screen/walimurid/parent_billing.dart';
import 'package:manajemensekolah/screen/walimurid/parent_class_activity.dart';
import 'package:manajemensekolah/services/api_notification_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class NotificationListScreen extends StatefulWidget {
  final String role; // 'guru', 'admin', 'wali'

  const NotificationListScreen({super.key, required this.role});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ApiNotificationService _apiService = ApiNotificationService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  Color _getPrimaryColor() {
    switch (widget.role) {
      case 'guru':
      case 'teacher':
        return ColorUtils.corporateBlue600;
      case 'admin':
        return ColorUtils.corporateBlue700;
      case 'wali':
      case 'parent':
        return ColorUtils.success600;
      default:
        return ColorUtils.corporateBlue600;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notifs = await _apiService.getNotifications(role: widget.role);
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.markAsRead(id);
      setState(() {
        _notifications.removeWhere((n) => n['id'].toString() == id);
      });
    } catch (e) {
      if (kDebugMode) print('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);
      setState(
        () => _notifications.removeWhere((n) => n['id'].toString() == id),
      );
    } catch (e) {
      if (kDebugMode) print('Error deleting notification: $e');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.markAllRead();
      setState(() {
        _notifications.clear();
      });
    } catch (e) {
      if (kDebugMode) print('Error marking all read: $e');
    }
  }

  bool _isUnread(Map<String, dynamic> n) {
    if (n['is_read'] is bool) return !(n['is_read'] as bool);
    if (n['is_read'] is int) return n['is_read'] != 1;
    return true;
  }

  int get _unreadCount => _notifications.where((n) => _isUnread(n)).length;

  bool get _hasUnread => _notifications.any((n) => _isUnread(n));

  Color _getColor(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return ColorUtils.success600;
      case 'announcement':
      case 'pengumuman':
        return ColorUtils.corporateBlue600;
      case 'class_activity':
      case 'activity':
        return ColorUtils.warning600;
      case 'reminder_teaching':
        return const Color(0xFF7C3AED);
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return const Color(0xFF0D9488);
      default:
        return ColorUtils.slate500;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return Icons.receipt_long_rounded;
      case 'announcement':
      case 'pengumuman':
        return Icons.campaign_rounded;
      case 'class_activity':
      case 'activity':
        return Icons.assignment_rounded;
      case 'reminder_teaching':
        return Icons.class_rounded;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return Icons.grade_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  void _handleTap(Map<String, dynamic> notif) {
    final type = notif['type'];

    if (widget.role == 'wali' || widget.role == 'parent') {
      if (type == 'bill') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParentBillingScreen()),
        );
        return;
      } else if (type == 'class_activity') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParentClassActivityScreen()),
        );
        return;
      }
    } else if (widget.role == 'guru' || widget.role == 'teacher') {
      if (type == 'class_activity') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClassActifityScreen()),
        );
        return;
      }
    }

    if (type == 'announcement' || type == 'pengumuman') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnouncementScreen()),
      );
    } else if (type == 'grade' || type == 'nilai' || type == 'exam_score') {
      _showDetailDialog(notif);
    }
  }

  void _showDetailDialog(Map<String, dynamic> notif) {
    final color = _getColor(notif['type'] ?? 'general');
    final icon = _getIcon(notif['type'] ?? 'general');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header (Pattern #10)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['title'] ?? 'Informasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _formatDate(notif['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                notif['body'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: ColorUtils.slate700,
                  height: 1.6,
                ),
              ),
            ),
            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tutup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final unread = _unreadCount;
        final primaryColor = _getPrimaryColor();

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              _buildHeader(context, languageProvider, primaryColor, unread),
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(itemCount: 8, infoTagCount: 1)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: primaryColor,
                        child: _notifications.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                itemCount: _notifications.length,
                                itemBuilder: (context, index) =>
                                    _buildNotificationCard(
                                      _notifications[index],
                                    ),
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LanguageProvider languageProvider,
    Color primaryColor,
    int unread,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Notifications',
                        'id': 'Notifikasi',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (unread > 0) ...[
                      SizedBox(height: 2),
                      Text(
                        '$unread ${languageProvider.getTranslatedText({'en': 'unread', 'id': 'belum dibaca'})}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action: Mark all read
              if (_hasUnread)
                IconButton(
                  onPressed: _markAllRead,
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.done_all_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  tooltip: languageProvider.getTranslatedText({
                    'en': 'Mark all as read',
                    'id': 'Tandai semua dibaca',
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 38,
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Tidak Ada Notifikasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Semua notifikasi akan muncul di sini.',
                style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = !_isUnread(notif);
    final type = notif['type'] ?? 'general';
    final color = isRead ? ColorUtils.slate400 : _getColor(type);

    return Dismissible(
      key: Key(notif['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ColorUtils.error600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteNotification(notif['id'].toString()),
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markAsRead(notif['id'].toString());
          _handleTap(notif);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead
                  ? ColorUtils.slate200
                  : color.withValues(alpha: 0.35),
              width: isRead ? 1.0 : 1.5,
            ),
            boxShadow: ColorUtils.corporateShadow(
              elevation: isRead ? 0.5 : 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar for unread
                  if (!isRead)
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isRead ? 14 : 12,
                        14,
                        14,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(_getIcon(type), color: color, size: 22),
                          ),
                          SizedBox(width: 12),
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: isRead
                                              ? ColorUtils.slate600
                                              : ColorUtils.slate900,
                                        ),
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  notif['body'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRead
                                        ? ColorUtils.slate400
                                        : ColorUtils.slate600,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildInfoTag(
                                      Icons.access_time_rounded,
                                      _formatDate(notif['created_at']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate500),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
