import 'dart:io' show Platform, exit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/update_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:restart_app/restart_app.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class UpdatePromptWrapper extends ConsumerWidget {
  final Widget child;

  const UpdatePromptWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to update state changes
    ref.listen<UpdateState>(updateProvider, (previous, next) {
      if (next.type == UpdateType.shorebirdPatch &&
          previous?.type != UpdateType.shorebirdPatch) {
        final navContext = navigatorKey.currentContext;
        if (navContext != null) {
          _showShorebirdPrompt(navContext, ref);
        }
      } else if (next.type == UpdateType.nativeUpdate &&
          previous?.type != UpdateType.nativeUpdate) {
        final navContext = navigatorKey.currentContext;
        if (navContext != null) {
          final isAndroid = Platform.isAndroid;
          final storeUrl = isAndroid
              ? 'https://play.google.com/store/apps/details?id=com.kamillabs.kamiledu'
              : 'https://apps.apple.com/app/idYOUR_APP_ID'; // Replace with real ID

          NativeUpdatePrompt.show(
            context: navContext,
            version: next.version ?? 'Terbaru',
            storeUrl: storeUrl,
          );
        }
      }
    });

    return child;
  }

  void _showShorebirdPrompt(BuildContext context, WidgetRef ref) {
    AppBottomSheet.show(
      context: context,
      title: 'Update Tersedia',
      subtitle:
          'Versi terbaru telah diunduh. Aplikasi akan dimuat ulang '
          'untuk menerapkan perubahan.',
      icon: Icons.auto_fix_high_rounded,
      primaryColor: const Color(0xFF143068), // Brand dark blue
      isDismissible: false,
      enableDrag: false,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kami telah melakukan perbaikan kecil dan peningkatan '
            'performa. Tap "Muat Ulang Aplikasi" — pembaruan akan '
            'otomatis aktif saat aplikasi terbuka kembali.',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Muat Ulang Aplikasi',
        secondaryLabel: 'Nanti Saja',
        primaryColor: const Color(0xFF143068),
        onPrimary: () async {
          AppLogger.info(
            'update',
            'User opted to close app to apply Shorebird patch.',
          );
          // Persist the patch number *before* exit so the next
          // cold-launch poll knows the user has already seen this
          // pop-up. UpdateNotifier.checkUpdates auto-clears this
          // marker once currentPatch catches up to it (i.e. the
          // patch actually applied) so a future update can fire
          // the dialog again.
          await ref.read(updateProvider.notifier).acknowledgeCurrentPatch();
          if (context.mounted) {
            SnackBarUtils.showInfo(
              context,
              'Memuat ulang aplikasi untuk menerapkan pembaruan...',
            );
          }

          await Future.delayed(const Duration(milliseconds: 1000));
          if (Platform.isAndroid) {
            try {
              const platform = MethodChannel('com.kamillabs.kamiledu/restart');
              await platform.invokeMethod('restartApp');
            } catch (e) {
              AppLogger.error('update', 'Failed to invoke native restart: $e');
              exit(0); // Fallback to manual close just in case
            }
          } else {
            await Restart.restartApp(mode: RestartMode.process);
          }
        },
        onSecondary: () async {
          // "Nanti Saja" is an explicit opt-out for *this specific*
          // patch number. The user gets the dialog again when a
          // newer patch ships, not on the next 15-min poll.
          await ref.read(updateProvider.notifier).acknowledgeCurrentPatch();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

/// A custom widget to show Play Store updates using AppBottomSheet style.
class NativeUpdatePrompt {
  NativeUpdatePrompt._();

  static Future<void> show({
    required BuildContext context,
    required String version,
    required String storeUrl,
  }) {
    final navContext = navigatorKey.currentContext ?? context;
    final isAndroid = Platform.isAndroid;
    final storeName = isAndroid ? 'Play Store' : 'App Store';

    return AppBottomSheet.show(
      context: navContext,
      title: 'Versi Baru Tersedia',
      subtitle: 'Versi $version tersedia di $storeName.',
      icon: Icons.system_update_rounded,
      primaryColor: const Color(0xFF143068),
      isDismissible: false,
      enableDrag: false,
      content: const Text(
        'Pembaruan besar tersedia dengan fitur-fitur baru yang menarik. Segera perbarui aplikasi Anda untuk terus menggunakan layanan kami.',
        style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Perbarui Sekarang',
        secondaryLabel: 'Nanti Saja',
        primaryColor: const Color(0xFF143068),
        onPrimary: () async {
          final url = Uri.parse(storeUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        onSecondary: () {
          Navigator.pop(navContext);
        },
      ),
    );
  }
}
