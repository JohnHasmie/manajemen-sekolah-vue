import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/login_helper.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/selection_helper.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/otp_helper.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/response_handler.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/error_handler.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/data_persistence_helper.dart';

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
      selectedSchool: selectedSchool == _sentinel
          ? this.selectedSchool
          : selectedSchool as Map<String, dynamic>?,
      userData: userData == _sentinel
          ? this.userData
          : userData as Map<String, dynamic>?,
      currentEmail: currentEmail == _sentinel
          ? this.currentEmail
          : currentEmail as String?,
      otpCode: otpCode == _sentinel ? this.otpCode : otpCode as String?,
      lastResponse: lastResponse == _sentinel
          ? this.lastResponse
          : lastResponse as AuthResponse?,
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

class AuthNotifier extends Notifier<AuthState> {
  late final LoginHelper _loginHelper;
  late final SelectionHelper _selectionHelper;
  late final OtpHelper _otpHelper;
  late final ResponseHandler _responseHandler;
  late final ErrorHandler _errorHandler;
  late final DataPersistenceHelper _persistenceHelper;

  @override
  AuthState build() {
    _initializeHelpers();
    return const AuthState();
  }

  void _initializeHelpers() {
    _persistenceHelper = DataPersistenceHelper();
    _responseHandler = ResponseHandler(persistenceHelper: _persistenceHelper);
    _errorHandler = ErrorHandler();
    _loginHelper = LoginHelper(
      updateState: (newState) => state = newState,
      updateStateFromAsync: (newState) => state = newState,
      responseHandler: _responseHandler,
      errorHandler: _errorHandler,
      clearAllData: clearAllData,
    );
    _selectionHelper = SelectionHelper(
      updateState: (newState) => state = newState,
      responseHandler: _responseHandler,
    );
    _otpHelper = OtpHelper(
      updateState: (newState) => state = newState,
      responseHandler: _responseHandler,
    );
  }

  void setServerConnected(bool connected) {
    state = state.copyWith(isServerConnected: connected);
  }

  void resetToLogin() {
    state = state.copyWith(
      step: AuthStep.login,
      isLoading: false,
      lastResponse: null,
    );
  }

  Future<void> clearAllData() async {
    final prefs = PreferencesService();
    await prefs.clear();
    await LocalCacheService.clearAll();
    AppLogger.info('auth_controller', 'All local data and cache cleared');
  }

  Future<AuthResponse> login(String email, String password) async {
    return await _loginHelper.login(email, password, state);
  }

  Future<AuthResponse> signInWithGoogle() async {
    return await _loginHelper.signInWithGoogle(state);
  }

  Future<AuthResponse> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? serverAuthCode,
  }) async {
    return await _loginHelper.googleLogin(
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      idToken: idToken,
      serverAuthCode: serverAuthCode,
      currentState: state,
    );
  }

  Future<AuthResponse> selectSchool(String schoolId) async {
    return await _selectionHelper.selectSchool(schoolId, state);
  }

  Future<AuthResponse> selectRole(String role) async {
    return await _selectionHelper.selectRole(role, state);
  }

  Future<AuthResponse> verifyOtp(String otp) async {
    return await _otpHelper.verifyOtp(otp, state);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
  isAutoDispose: true,
);
