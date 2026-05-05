// Class finance list — Mockup #13 drill landing.
//
// Pushed from the navy-tinted ClassReportDrillCard on the Tagihan
// tab and from the dashboard PendingInboxCard's "Tagihan menunggak"
// shortcut. Shows a scrollable list of the school's classes; tapping
// a card pushes the existing ClassFinanceReportScreen for that class.
//
// Standalone screen so the entry points don't need to know about the
// underlying classroom data shape — a thin StatefulWidget that owns
// its own fetch with a 15s soft timeout.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';

class ClassFinanceListScreen extends StatefulWidget {
  const ClassFinanceListScreen({super.key});

  @override
  State<ClassFinanceListScreen> createState() => _ClassFinanceListScreenState();
}

class _ClassFinanceListScreenState extends State<ClassFinanceListScreen> {
  List<Map<String, dynamic>> _classes = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await ApiService()
          .get('/classes?limit=1000')
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final list = _parseClasses(raw);
      AppLogger.debug('class-finance-list', 'loaded ${list.length} classes');
      setState(() {
        _classes = list;
        _loading = false;
      });
    } on TimeoutException catch (e) {
      AppLogger.error('class-finance-list', 'fetch timeout: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Permintaan ke server terlalu lama (>15s). '
            'Cek koneksi backend lalu coba lagi.';
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.error('class-finance-list', e, st);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseClasses(dynamic raw) {
    final list = <Map<String, dynamic>>[];
    if (raw is Map) {
      final data = raw['data'];
      if (data is List) {
        for (final item in data) {
          if (item is Map) list.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) list.add(Map<String, dynamic>.from(item));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        onRefresh: _load,
        color: navy,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(navy)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: _ErrorPanel(message: _error.toString(), onRetry: _load),
              )
            else if (_classes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: 'Belum ada data kelas',
                  subtitle:
                      'Data kelas akan muncul di sini setelah kelas dibuat.',
                  icon: Icons.class_outlined,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                sliver: SliverList.builder(
                  itemCount: _classes.length,
                  itemBuilder: (context, i) =>
                      _ClassCard(data: _classes[i], navy: navy),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color navy) {
    return Container(
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient('admin'),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => AppNavigator.pop(context),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Operasional · Keuangan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Laporan per kelas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih kelas untuk lihat breakdown tagihan & pembayaran.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color navy;
  const _ClassCard({required this.data, required this.navy});

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] ?? '').toString();
    final name = (data['name'] ?? data['nama'] ?? '-').toString();
    final studentCount =
        (data['students_count'] ??
                data['student_count'] ??
                data['jumlah_siswa'] ??
                0)
            .toString();
    final tingkat = data['grade_level'] ?? data['tingkat'];
    final subtitle = tingkat != null
        ? 'Tingkat $tingkat · $studentCount siswa'
        : '$studentCount siswa';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (id.isEmpty) return;
            AppNavigator.push(
              context,
              ClassFinanceReportScreen(classId: id, className: name),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.class_, color: navy, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.slate500,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Gagal memuat daftar kelas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                color: ColorUtils.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Muat ulang',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
}
