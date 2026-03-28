/// service_locator.dart - Dependency injection setup using get_it.
/// Like Laravel's Service Container (`app()->bind()`, `app()->singleton()`).
/// In Vue terms, this is like providing global services via `app.provide()`.
///
/// Registers all singleton services at app startup. Screens and other services
/// can then access them via `getIt<ServiceType>()` instead of creating new instances.
library;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/grades/services/grade_recap_service.dart';
import 'package:manajemensekolah/features/report_cards/services/report_card_service.dart';
import 'package:manajemensekolah/features/notifications/services/notification_service.dart';
import 'package:manajemensekolah/features/settings/services/settings_service.dart';
import 'package:manajemensekolah/features/settings/services/academic_service.dart';
import 'package:manajemensekolah/features/announcements/services/announcement_service.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/features/class_activity/services/class_activity_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/recommendations/services/recommendation_service.dart';

/// Global service locator instance. Like Laravel's `app()` helper.
/// Access any registered service via `getIt<ServiceType>()`.
final GetIt getIt = GetIt.instance;

/// Registers all application services as singletons.
/// Called once during app initialization (before runApp).
/// Like Laravel's `AppServiceProvider::register()`.
Future<void> setupServiceLocator() async {
  // Core services
  getIt.registerLazySingleton<PreferencesService>(PreferencesService.new);
  getIt.registerLazySingleton<SecureStorageService>(SecureStorageService.new);
  getIt.registerLazySingleton<TokenService>(TokenService.new);
  getIt.registerLazySingleton<Dio>(() => dioClient);

  // Feature services
  getIt.registerLazySingleton<ApiGradeRecapService>(ApiGradeRecapService.new);
  getIt.registerLazySingleton<ApiRaportService>(ApiRaportService.new);
  getIt.registerLazySingleton<ApiNotificationService>(ApiNotificationService.new);
  getIt.registerLazySingleton<ApiSettingsService>(ApiSettingsService.new);
  getIt.registerLazySingleton<ApiAcademicServices>(ApiAcademicServices.new);
  getIt.registerLazySingleton<ApiAnnouncementService>(ApiAnnouncementService.new);
  getIt.registerLazySingleton<ApiClassService>(ApiClassService.new);
  getIt.registerLazySingleton<ApiTeacherService>(ApiTeacherService.new);
  getIt.registerLazySingleton<ApiStudentService>(ApiStudentService.new);
  getIt.registerLazySingleton<ApiSubjectService>(ApiSubjectService.new);
  getIt.registerLazySingleton<ApiScheduleService>(ApiScheduleService.new);
  getIt.registerLazySingleton<ApiClassActivityService>(ApiClassActivityService.new);
  getIt.registerLazySingleton<ApiTourService>(ApiTourService.new);
  getIt.registerLazySingleton<ApiRecommendationService>(ApiRecommendationService.new);
}
