// Typed domain model for the account/profile surface.
//
// The profile screen previously read its data straight out of a
// `Map<String, dynamic>` assembled from two sources:
//
//   1. The cached `user` blob in [PreferencesService] (jsonDecoded), and
//   2. The live `userData` map on the dashboard state, which is spread
//      *over* the cached blob so fresher dashboard values win.
//
// This model captures that merged shape with exact field types,
// nullability, and — importantly — the same key fallbacks and display
// defaults the screen used inline (e.g. `name` ?? `nama` ?? 'Pengguna').
// Parsing happens once in [AccountProfile.fromMap]; the screen reads
// typed getters instead of digging through the map.
//
// Convention: plain immutable PODO with a `fromMap` factory, matching
// sibling models like `AdminActivitySummary`. The fallback logic is too
// bespoke (multiple Indonesian/English key aliases + UI display
// placeholders baked into the same accessor) to express cleanly with
// freezed's `@JsonKey`, so a hand-written factory keeps behavior 1:1.
library;

/// Immutable view of the signed-in user's profile as rendered by the
/// account/profile screen.
///
/// All fields are non-null `String`s holding the already-resolved
/// display value (including the `'-'` / `'Pengguna'` placeholders the
/// old inline getters produced), so the UI layer stays free of
/// null-handling. [role] holds the raw role string ('admin', 'guru',
/// 'wali', …) — label mapping stays in the screen.
class AccountProfile {
  /// Display name. Resolved from `name` ?? `nama`, defaulting to
  /// `'Pengguna'` when both are absent/blank.
  final String name;

  /// Email. Resolved from `email`, defaulting to `'-'`.
  final String email;

  /// Phone number. Resolved from `phone` ?? `no_telepon`, default `'-'`.
  final String phone;

  /// Street address. Resolved from `address` ?? `alamat`, default `'-'`.
  final String address;

  /// Active school name. Resolved from `school_name` ?? `nama_sekolah`,
  /// default `'-'`.
  final String schoolName;

  /// Raw role string ('admin' / 'guru' / 'wali' / …). The screen maps
  /// this to a localized label and an accent color.
  final String role;

  const AccountProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.schoolName,
    required this.role,
  });

  /// Default role used before any data has loaded, matching the
  /// screen's original `String _role = 'wali'` seed.
  static const String defaultRole = 'wali';

  /// An empty profile carrying only the default role — equivalent to
  /// the screen's initial state before [loadFrom] runs.
  static const AccountProfile empty = AccountProfile(
    name: 'Pengguna',
    email: '-',
    phone: '-',
    address: '-',
    schoolName: '-',
    role: defaultRole,
  );

  /// Parse a merged user map into the typed profile.
  ///
  /// [map] is the result of spreading the dashboard `userData` over the
  /// cached `user` blob (dashboard values win) — i.e. the exact map the
  /// screen used to read keys from for the name/email/phone/address/
  /// school fields.
  ///
  /// [role] is passed in already resolved rather than read from [map]:
  /// the screen sources role *only* from the dashboard `userData`
  /// (falling back to the prior role), which is a narrower source than
  /// the merged map. Keeping it a parameter preserves that 1:1.
  factory AccountProfile.fromMap(
    Map<String, dynamic> map, {
    String role = defaultRole,
  }) {
    return AccountProfile(
      name: (map['name'] ?? map['nama'] ?? 'Pengguna').toString(),
      email: (map['email'] ?? '-').toString(),
      phone: (map['phone'] ?? map['no_telepon'] ?? '-').toString(),
      address: (map['address'] ?? map['alamat'] ?? '-').toString(),
      schoolName: (map['school_name'] ?? map['nama_sekolah'] ?? '-')
          .toString(),
      role: role,
    );
  }

  /// First letter of [name], uppercased, for the avatar monogram.
  /// Returns `'?'` when the name is blank.
  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}
