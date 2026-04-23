import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionUIBuilderMixin on State<DaySessionManagementSheet> {
  // Abstract getters/methods that must be implemented by the state
  List<dynamic> get sessions;
  void showAddEditSessionDialog({Map<String, dynamic>? session});
  void showCopyDialog();
  Future<void> deleteSession(String id);

  Widget buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget buildHeader(String dayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jadwal $dayName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sessions.length} jam pelajaran terdaftar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    final hasCopyOption = widget.allDays.any((d) {
      final dId = d['id'].toString();
      return dId != widget.day['id'].toString() &&
          (widget.allSessionsByDay[dId] ?? []).isNotEmpty;
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_outlined,
              size: 32,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada jadwal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tambah jam pelajaran di bawah',
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
          ),
          if (hasCopyOption) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: showCopyDialog,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin dari hari lain'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ColorUtils.corporateBlue600),
                foregroundColor: ColorUtils.corporateBlue600,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildSessionList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionItem(session);
      },
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
      ),
      child: Row(
        children: [
          _buildSessionNumber(session),
          const SizedBox(width: AppSpacing.md),
          _buildSessionInfo(session),
          _buildSessionActions(session),
        ],
      ),
    );
  }

  Widget _buildSessionNumber(Map<String, dynamic> session) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          '${session['hour_number']}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.corporateBlue600,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfo(Map<String, dynamic> session) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jam ke-${session['hour_number']}',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
          ),
          Text(
            '${session['start_time']} – ${session['end_time']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionActions(Map<String, dynamic> session) {
    return Row(
      children: [
        buildActionButton(
          icon: Icons.edit_rounded,
          color: ColorUtils.corporateBlue600,
          onTap: () => showAddEditSessionDialog(session: session),
        ),
        const SizedBox(width: AppSpacing.sm),
        buildActionButton(
          icon: Icons.delete_rounded,
          color: ColorUtils.error600,
          onTap: () => deleteSession(session['id'].toString()),
        ),
      ],
    );
  }

  Widget buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: showAddEditSessionDialog,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Tambah Jam Pelajaran',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.corporateBlue600,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
