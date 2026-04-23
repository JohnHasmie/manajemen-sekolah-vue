import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';

class ErrorHandler {
  AuthResponse handleError(Object error, String? email) {
    final errorStr = error.toString().toLowerCase();
    final isUnregistered =
        errorStr.contains('email tidak terdaftar') ||
        errorStr.contains('email not registered') ||
        errorStr.contains('user not found') ||
        errorStr.contains('user tidak ditemukan') ||
        errorStr.contains('no account found') ||
        errorStr.contains('akun tidak ditemukan') ||
        errorStr.contains('belum terdaftar') ||
        errorStr.contains('tidak memiliki akun');

    if (isUnregistered) {
      return AuthResponse(AuthEvent.unregistered, unregisteredEmail: email);
    }

    final messageMap =
        (errorStr.contains('401') || errorStr.contains('unauthorized'))
        ? AppLocalizations.authInvalidCredentials
        : {
            'en': error.toString().replaceAll('Exception: ', ''),
            'id': error.toString().replaceAll('Exception: ', ''),
          };

    return AuthResponse(AuthEvent.error, messageMap: messageMap);
  }
}
