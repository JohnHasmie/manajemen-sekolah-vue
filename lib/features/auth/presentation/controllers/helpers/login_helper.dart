import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/response_handler.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/error_handler.dart';

class LoginHelper {
  final GoogleSignIn _googleSignIn;
  final Function(AuthState) updateState;
  final Function(AuthState) updateStateFromAsync;
  final ResponseHandler responseHandler;
  final ErrorHandler errorHandler;
  final Function() clearAllData;

  LoginHelper({
    required this.updateState,
    required this.updateStateFromAsync,
    required this.responseHandler,
    required this.errorHandler,
    required this.clearAllData,
  }) : _googleSignIn = GoogleSignIn(
         scopes: ['email'],
         clientId: kIsWeb
             ? '631663251271-q5fmm1j2r4hko6fkicn5mml5vt8r3cnb.apps.'
                   'googleusercontent.com'
             : null,
       );

  Future<AuthResponse> login(
    String email,
    String password,
    AuthState currentState,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      final response = AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.emailPasswordNotEmpty,
      );
      updateState(currentState.copyWith(lastResponse: response));
      return response;
    }

    updateState(
      currentState.copyWith(
        isLoading: true,
        currentEmail: email,
        lastResponse: null,
      ),
    );
    await clearAllData();

    try {
      final responseData = await AuthService.login(email, password);
      final response = await responseHandler.handleLoginResponse(
        responseData,
        currentState,
        updateState,
      );
      // Only update lastResponse if the response handler didn't already
      // transition to a new step (school/role selection returns AuthEvent.none
      // after updating state — overwriting with stale currentState would
      // revert the step back to login).
      if (response.event != AuthEvent.none) {
        updateState(currentState.copyWith(lastResponse: response));
      }
      return response;
    } catch (e) {
      final response = errorHandler.handleError(e, email);
      updateState(
        currentState.copyWith(isLoading: false, lastResponse: response),
      );
      return response;
    }
  }

  Future<AuthResponse> signInWithGoogle(AuthState currentState) async {
    updateState(currentState.copyWith(isLoading: true, lastResponse: null));
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        updateState(currentState.copyWith(isLoading: false));
        return AuthResponse(AuthEvent.none);
      }

      final auth = await account.authentication;
      final response = await googleLogin(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        idToken: auth.idToken,
        serverAuthCode: account.serverAuthCode,
        currentState: currentState,
      );

      if (response.event != AuthEvent.none) {
        updateState(currentState.copyWith(lastResponse: response));
      }
      return response;
    } catch (error) {
      final response = AuthResponse(AuthEvent.error, message: error.toString());
      updateState(
        currentState.copyWith(isLoading: false, lastResponse: response),
      );
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
    required AuthState currentState,
  }) async {
    updateState(currentState.copyWith(isLoading: true, currentEmail: email));
    try {
      final responseData = await AuthService.googleLogin(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
        serverAuthCode: serverAuthCode,
      );
      return await responseHandler.handleLoginResponse(
        responseData,
        currentState,
        updateState,
      );
    } catch (e) {
      updateState(currentState.copyWith(isLoading: false));
      await clearAllData();
      return errorHandler.handleError(e, email);
    }
  }
}
