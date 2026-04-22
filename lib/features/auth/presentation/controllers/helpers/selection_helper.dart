import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/response_handler.dart';

class SelectionHelper {
  final Function(AuthState) updateState;
  final ResponseHandler responseHandler;

  SelectionHelper({required this.updateState, required this.responseHandler});

  Future<AuthResponse> selectSchool(
    String schoolId,
    AuthState currentState,
  ) async {
    updateState(
      currentState.copyWith(
        isLoading: true,
        selectedSchool: {'id': schoolId},
        lastResponse: null,
      ),
    );
    try {
      Map<String, dynamic> responseData;
      if (currentState.otpCode != null && currentState.currentEmail != null) {
        responseData = await AuthService.verifyOtp(
          currentState.currentEmail!,
          currentState.otpCode!,
          schoolId: schoolId,
        );
      } else {
        responseData = await AuthService.switchSchool(schoolId);
      }
      final response = await responseHandler.handleLoginResponse(
        responseData,
        currentState,
        updateState,
      );
      // Only update lastResponse if the response handler didn't already
      // transition to a new step (school/role selection returns AuthEvent.none
      // after updating state — overwriting with stale currentState would
      // revert the step).
      if (response.event != AuthEvent.none) {
        updateState(currentState.copyWith(lastResponse: response));
      }
      return response;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      updateState(
        currentState.copyWith(isLoading: false, lastResponse: response),
      );
      return response;
    }
  }

  Future<AuthResponse> selectRole(String role, AuthState currentState) async {
    updateState(currentState.copyWith(isLoading: true, lastResponse: null));
    try {
      final schoolId =
          currentState.selectedSchool?['id']?.toString() ??
          currentState.selectedSchool?['school_id']?.toString();
      Map<String, dynamic> responseData;

      if (currentState.otpCode != null && currentState.currentEmail != null) {
        responseData = await AuthService.verifyOtp(
          currentState.currentEmail!,
          currentState.otpCode!,
          schoolId: schoolId,
          role: role,
        );
      } else {
        responseData = await AuthService.switchSchool(
          schoolId ?? '',
          role: role,
        );
      }
      final response = await responseHandler.handleLoginResponse(
        responseData,
        currentState,
        updateState,
      );
      // Only update lastResponse if the response handler didn't already
      // transition to a new step — avoids overwriting with stale state.
      if (response.event != AuthEvent.none) {
        updateState(currentState.copyWith(lastResponse: response));
      }
      return response;
    } catch (e) {
      final response = AuthResponse(AuthEvent.error, message: e.toString());
      updateState(
        currentState.copyWith(isLoading: false, lastResponse: response),
      );
      return response;
    }
  }
}
