import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/response_handler.dart';

class OtpHelper {
  final Function(AuthState) updateState;
  final ResponseHandler responseHandler;

  OtpHelper({required this.updateState, required this.responseHandler});

  Future<AuthResponse> verifyOtp(String otp, AuthState currentState) async {
    if (currentState.currentEmail == null) {
      return AuthResponse(
        AuthEvent.error,
        messageMap: {'en': 'Email not set', 'id': 'Email belum diatur'},
      );
    }
    updateState(
      currentState.copyWith(isLoading: true, otpCode: otp, lastResponse: null),
    );
    try {
      final response = await AuthService.verifyOtp(
        currentState.currentEmail!,
        otp,
      );
      final result = await responseHandler.handleLoginResponse(
        response,
        currentState,
        updateState,
      );
      if (result.event == AuthEvent.error) {
        updateState(currentState.copyWith(step: AuthStep.otpVerification));
      }
      updateState(currentState.copyWith(lastResponse: result));
      return result;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      updateState(
        currentState.copyWith(
          isLoading: false,
          step: AuthStep.otpVerification,
          lastResponse: response,
        ),
      );
      return response;
    }
  }
}
