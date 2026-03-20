/// user.dart - Authenticated user data model.
/// Like Laravel's User Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for the logged-in user object stored in Vuex/Pinia.
library;

/// Represents an authenticated user of the school management system.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [nama]: User's display name.
/// - [email]: Login email address.
/// - [password]: User's password (used only for dummy/seed data - real auth uses tokens).
/// - [role]: Authorization role string - one of 'admin', 'guru' (teacher), 'staff', or 'wali' (parent).
///   Like Laravel's role/permission system (e.g., Spatie roles).
/// - [kelas]: Optional class assignment for teachers (nullable for non-teacher roles).
class User {
  final String id;
  final String nama;
  final String email;
  final String password;
  final String role;
  final String? kelas;

  /// Creates a [User] instance.
  /// [kelas] is optional since only teachers may have an assigned class.
  User({
    required this.id,
    required this.nama,
    required this.email,
    required this.password,
    required this.role,
    this.kelas,
  });
}