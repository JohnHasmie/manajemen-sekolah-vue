import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

enum AuthStep { login, schoolSelection, roleSelection }

enum AuthEvent { none, success, requiresOtp, unregistered, error }

class AuthState {
  final bool isLoading;
  final bool isServerConnected;
  final AuthStep step;
  final List<dynamic> schoolList;
  final List<dynamic> roleList;
  final Map<String, dynamic>? selectedSchool;
  final Map<String, dynamic>? userData;
  final String? currentEmail;
  final String? otpCode;

  const AuthState({
    this.isLoading = false,
    this.isServerConnected = true,
    this.step = AuthStep.login,
    this.schoolList = const [],
    this.roleList = const [],
    this.selectedSchool,
    this.userData,
    this.currentEmail,
    this.otpCode,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isServerConnected,
    AuthStep? step,
    List<dynamic>? schoolList,
    List<dynamic>? roleList,
    Map<String, dynamic>? selectedSchool,
    Map<String, dynamic>? userData,
    String? currentEmail,
    String? otpCode,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isServerConnected: isServerConnected ?? this.isServerConnected,
      step: step ?? this.step,
      schoolList: schoolList ?? this.schoolList,
      roleList: roleList ?? this.roleList,
      selectedSchool: selectedSchool ?? this.selectedSchool,
      userData: userData ?? this.userData,
      currentEmail: currentEmail ?? this.currentEmail,
      otpCode: otpCode ?? this.otpCode,
    );
  }
}

class AuthResponse {
  final AuthEvent event;
  final String? message;
  final Map<String, String>? messageMap;
  final String? debugOtp;

  AuthResponse(this.event, {this.message, this.messageMap, this.debugOtp});
}

class AuthNotifier extends AutoDisposeNotifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  void setServerConnected(bool connected) {
    state = state.copyWith(isServerConnected: connected);
  }

  void resetToLogin() {
    state = state.copyWith(step: AuthStep.login, isLoading: false);
  }

  Future<void> clearAllData() async {
    final prefs = PreferencesService();
    await prefs.clear();
    await LocalCacheService.clearAll();
    AppLogger.info('auth_controller', 'All local data and cache cleared');
  }

  Future<AuthResponse> login(String email, String password) async {
    state = state.copyWith(isLoading: true, currentEmail: email);
    await clearAllData();

    try {
      final responseData = await AuthService.login(email, password);
      return await _handleLoginResponse(responseData);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return _handleError(e);
    }
  }

  Future<AuthResponse> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken,
  }) async {
    state = state.copyWith(isLoading: true, currentEmail: email);
    try {
      final responseData = await AuthService.googleLogin(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
      );
      return await _handleLoginResponse(responseData);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      await clearAllData();
      return _handleError(e);
    }
  }

  Future<AuthResponse> selectSchool(String schoolId) async {
    state = state.copyWith(isLoading: true, selectedSchool: {'id': schoolId});
    try {
      Map<String, dynamic> responseData;
      if (state.otpCode != null && state.currentEmail != null) {
        responseData = await AuthService.verifyOtp(
          state.currentEmail!,
          state.otpCode!,
          schoolId: schoolId,
        );
      } else {
        // Assume Google Login generated a token earlier in this flow, or normal password fallback
        final prefs = PreferencesService();
        if (prefs.getString('token') != null) {
          responseData = await AuthService.switchSchool(schoolId);
        } else {
          // Password fallback - should not reach here usually since password isn't stored in state,
          // but if we are here we have no password. So switchSchool is standard.
          responseData = await AuthService.switchSchool(schoolId);
        }
      }
      return await _handleLoginResponse(responseData);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return AuthResponse(AuthEvent.error, message: e.toString());
    }
  }

  Future<AuthResponse> selectRole(String role) async {
    state = state.copyWith(isLoading: true);
    try {
      final schoolId =
          state.selectedSchool?['id']?.toString() ??
          state.selectedSchool?['school_id']?.toString();
      Map<String, dynamic> responseData;

      if (state.otpCode != null && state.currentEmail != null) {
        responseData = await AuthService.verifyOtp(
          state.currentEmail!,
          state.otpCode!,
          schoolId: schoolId,
          role: role,
        );
      } else {
        responseData = await AuthService.switchSchool(
          schoolId ?? '',
          role: role,
        );
      }
      return await _handleLoginResponse(responseData);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return AuthResponse(AuthEvent.error, message: e.toString());
    }
  }

  Future<AuthResponse> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true, otpCode: otp);
    try {
      final response = await AuthService.verifyOtp(state.currentEmail!, otp);
      return await _handleLoginResponse(response);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return AuthResponse(AuthEvent.error, message: e.toString());
    }
  }

  Future<AuthResponse> _handleLoginResponse(
    Map<String, dynamic> responseData,
  ) async {
    // 1. Check OTP requirement
    if (responseData['require_otp'] == true ||
        responseData['otp_debug'] != null ||
        responseData['message'] == 'OTP sent to email') {
      state = state.copyWith(isLoading: false);
      return AuthResponse(
        AuthEvent.requiresOtp,
        debugOtp: responseData['otp_debug'],
      );
    }

    // 2. School Selection
    if (responseData['needsSchoolSelection'] == true) {
      if (responseData['sekolah_list'] == null ||
          (responseData['sekolah_list'] as List).isEmpty) {
        state = state.copyWith(isLoading: false);
        return AuthResponse(
          AuthEvent.error,
          messageMap: AppLocalizations.authAccountNotRegisteredInAnySchool,
        );
      }

      if (responseData['token'] != null) {
        await SecureStorageService().saveToken(responseData['token']);
        final prefs = PreferencesService();
        await prefs.setString('token', responseData['token']);
      }

      state = state.copyWith(
        step: AuthStep.schoolSelection,
        schoolList: responseData['sekolah_list'],
        userData: responseData['user'],
        isLoading: false,
      );
      return AuthResponse(AuthEvent.none);
    }

    // 3. Role Selection
    if (responseData['needsRoleSelection'] == true) {
      if (responseData['token'] != null) {
        await SecureStorageService().saveToken(responseData['token']);
        final prefs = PreferencesService();
        await prefs.setString('token', responseData['token']);
      }

      if (responseData['role_list'] == null ||
          (responseData['role_list'] as List).isEmpty) {
        state = state.copyWith(isLoading: false);
        return AuthResponse(
          AuthEvent.error,
          messageMap: AppLocalizations.authRolesNotAvailable,
        );
      }

      state = state.copyWith(
        step: AuthStep.roleSelection,
        roleList: responseData['role_list'],
        userData: responseData['user'],
        selectedSchool:
            responseData['school'] ??
            responseData['sekolah'] ??
            state.selectedSchool,
        isLoading: false,
      );
      return AuthResponse(AuthEvent.none);
    }

    // 4. Successful login
    if (responseData['token'] == null || responseData['user'] == null) {
      state = state.copyWith(isLoading: false);
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authIncompleteLoginData,
      );
    }

    await _saveLoginData(responseData);
    state = state.copyWith(isLoading: false);

    final user = User.fromJson(responseData['user']);
    final String userRole = user.role;
    if (userRole.isEmpty) {
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authUserRoleNotFound,
      );
    }

    return AuthResponse(AuthEvent.success, message: userRole);
  }

  Future<void> _saveLoginData(Map<String, dynamic> responseData) async {
    final secureStorage = SecureStorageService();
    await secureStorage.saveToken(responseData['token']);
    await secureStorage.saveUserData(
      responseData['user'] as Map<String, dynamic>,
    );
    await secureStorage.setForceLogout(false);

    final prefs = PreferencesService();
    await prefs.setString('token', responseData['token']);
    await prefs.setString('user', json.encode(responseData['user']));
    await prefs.setBool('force_logout', false);

    final userMap = responseData['user'] as Map<String, dynamic>?;
    if (userMap != null) {
      final user = User.fromJson(userMap);
      await AnalyticsService.setUser(
        userId: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
        schoolName: user.schoolName ?? '',
      );
      await AnalyticsService.logLogin(
        method: 'app_login',
        email: user.email,
        role: user.role,
      );
    }

    // Background FCM refresh
    Future(() async {
      try {
        final fcmService = FCMService();
        final token = fcmService.fcmToken ?? await fcmService.getSavedToken();
        if (token != null) {
          await fcmService.sendTokenToBackend(token);
        }
      } catch (e) {
        AppLogger.error('login', 'Failed to send FCM token: $e');
      }
    });
  }

  AuthResponse _handleError(Object error) {
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
      return AuthResponse(AuthEvent.unregistered);
    }

    final messageMap = (errorStr.contains('401') || errorStr.contains('unauthorized'))
        ? AppLocalizations.authInvalidCredentials
        : {'en': error.toString().replaceAll('Exception: ', ''), 'id': error.toString().replaceAll('Exception: ', '')};

    return AuthResponse(AuthEvent.error, messageMap: messageMap);
  }
}

final authProvider = AutoDisposeNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
