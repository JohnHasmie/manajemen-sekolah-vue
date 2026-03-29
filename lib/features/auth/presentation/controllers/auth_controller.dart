import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

enum AuthStep { login, schoolSelection, roleSelection, otpVerification }

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
  final AuthResponse? lastResponse;

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
    this.lastResponse,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isServerConnected,
    AuthStep? step,
    List<dynamic>? schoolList,
    List<dynamic>? roleList,
    Object? selectedSchool = _sentinel,
    Object? userData = _sentinel,
    Object? currentEmail = _sentinel,
    Object? otpCode = _sentinel,
    Object? lastResponse = _sentinel,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isServerConnected: isServerConnected ?? this.isServerConnected,
      step: step ?? this.step,
      schoolList: schoolList ?? this.schoolList,
      roleList: roleList ?? this.roleList,
      selectedSchool: selectedSchool == _sentinel ? this.selectedSchool : selectedSchool as Map<String, dynamic>?,
      userData: userData == _sentinel ? this.userData : userData as Map<String, dynamic>?,
      currentEmail: currentEmail == _sentinel ? this.currentEmail : currentEmail as String?,
      otpCode: otpCode == _sentinel ? this.otpCode : otpCode as String?,
      lastResponse: lastResponse == _sentinel ? this.lastResponse : lastResponse as AuthResponse?,
    );
  }

  static const Object _sentinel = Object();
}

class AuthResponse {
  final AuthEvent event;
  final String? message;
  final Map<String, String>? messageMap;
  final String? debugOtp;
  final String? unregisteredEmail;

  AuthResponse(
    this.event, {
    this.message,
    this.messageMap,
    this.debugOtp,
    this.unregisteredEmail,
  });
}

class AuthNotifier extends AutoDisposeNotifier<AuthState> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb
        ? '631663251271-q5fmm1j2r4hko6fkicn5mml5vt8r3cnb.apps.googleusercontent.com'
        : null,
  );

  @override
  AuthState build() {
    return const AuthState();
  }

  void setServerConnected(bool connected) {
    state = state.copyWith(isServerConnected: connected);
  }

  void resetToLogin() {
    state = state.copyWith(step: AuthStep.login, isLoading: false, lastResponse: null);
  }

  Future<void> clearAllData() async {
    final prefs = PreferencesService();
    await prefs.clear();
    await LocalCacheService.clearAll();
    AppLogger.info('auth_controller', 'All local data and cache cleared');
  }

  Future<AuthResponse> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      final response = AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.emailPasswordNotEmpty,
      );
      state = state.copyWith(lastResponse: response);
      return response;
    }

    state = state.copyWith(isLoading: true, currentEmail: email, lastResponse: null);
    await clearAllData();

    try {
      final responseData = await AuthService.login(email, password);
      final response = await _handleLoginResponse(responseData);
      state = state.copyWith(lastResponse: response);
      return response;
    } catch (e) {
      final response = _handleError(e, email);
      state = state.copyWith(isLoading: false, lastResponse: response);
      return response;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, lastResponse: null);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return AuthResponse(AuthEvent.none);
      }

      final auth = await account.authentication;
      final response = await googleLogin(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        idToken: auth.idToken,
        serverAuthCode: account.serverAuthCode,
      );

      state = state.copyWith(lastResponse: response);
      return response;
    } catch (error) {
      final response = AuthResponse(AuthEvent.error, message: error.toString());
      state = state.copyWith(isLoading: false, lastResponse: response);
      AppLogger.error('google_auth', 'Google Sign-In failed: $error');
      return response;
    }
  }

  Future<AuthResponse> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? serverAuthCode,
  }) async {
    state = state.copyWith(isLoading: true, currentEmail: email);
    try {
      final responseData = await AuthService.googleLogin(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
        serverAuthCode: serverAuthCode,
      );
      return await _handleLoginResponse(responseData);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      await clearAllData();
      return _handleError(e, email);
    }
  }

  Future<AuthResponse> selectSchool(String schoolId) async {
    state = state.copyWith(isLoading: true, selectedSchool: {'id': schoolId}, lastResponse: null);
    try {
      Map<String, dynamic> responseData;
      if (state.otpCode != null && state.currentEmail != null) {
        responseData = await AuthService.verifyOtp(
          state.currentEmail!,
          state.otpCode!,
          schoolId: schoolId,
        );
      } else {
        responseData = await AuthService.switchSchool(schoolId);
      }
      final response = await _handleLoginResponse(responseData);
      state = state.copyWith(lastResponse: response);
      return response;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      state = state.copyWith(isLoading: false, lastResponse: response);
      return response;
    }
  }

  Future<AuthResponse> selectRole(String role) async {
    state = state.copyWith(isLoading: true, lastResponse: null);
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
      final response = await _handleLoginResponse(responseData);
      state = state.copyWith(lastResponse: response);
      return response;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      state = state.copyWith(isLoading: false, lastResponse: response);
      return response;
    }
  }

  Future<AuthResponse> verifyOtp(String otp) async {
    if (state.currentEmail == null) {
      return AuthResponse(AuthEvent.error, messageMap: {'en': 'Email not set', 'id': 'Email belum diatur'});
    }
    state = state.copyWith(isLoading: true, otpCode: otp, lastResponse: null);
    try {
      final response = await AuthService.verifyOtp(state.currentEmail!, otp);
      final result = await _handleLoginResponse(response);
      if (result.event == AuthEvent.error) {
        state = state.copyWith(step: AuthStep.otpVerification);
      }
      state = state.copyWith(lastResponse: result);
      return result;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.otpVerification,
        lastResponse: response,
      );
      return response;
    }
  }

  Future<AuthResponse> _handleLoginResponse(
    Map<String, dynamic> responseData,
  ) async {
    if (responseData['require_otp'] == true ||
        responseData['otp_debug'] != null ||
        responseData['message'] == 'OTP sent to email') {
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.otpVerification,
        otpCode: responseData['otp_debug']?.toString(),
      );
      return AuthResponse(
        AuthEvent.requiresOtp,
        debugOtp: responseData['otp_debug']?.toString(),
      );
    }

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

  AuthResponse _handleError(Object error, String? email) {
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

    final messageMap = (errorStr.contains('401') ||
            errorStr.contains('unauthorized'))
        ? AppLocalizations.authInvalidCredentials
        : {
          'en': error.toString().replaceAll('Exception: ', ''),
          'id': error.toString().replaceAll('Exception: ', ''),
        };

    return AuthResponse(AuthEvent.error, messageMap: messageMap);
  }
}

final authProvider = AutoDisposeNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
