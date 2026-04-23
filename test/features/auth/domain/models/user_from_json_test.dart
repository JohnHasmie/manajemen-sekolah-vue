// CRUD data tests for User.fromJson + _standardizeJson.
//
// _standardizeJson normalises Indonesian key aliases (nama, peran, sekolah_id,
// nama_sekolah, foto_profil, user_id) to their English equivalents.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';

Map<String, dynamic> _base({Map<String, dynamic>? overrides}) => {
  'id': 'u-1',
  'name': 'Ahmad',
  'email': 'ahmad@school.id',
  'role': 'guru',
  ...?overrides,
};

void main() {
  // ---------------------------------------------------------------------------
  // id normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — id field', () {
    test('reads "id" directly', () {
      final u = User.fromJson(_base(overrides: {'id': 'u-42'}));
      expect(u.id, 'u-42');
    });

    test('falls back to "user_id"', () {
      final u = User.fromJson({
        'user_id': 'u-99',
        'name': 'A',
        'email': 'a@b.com',
        'role': 'guru',
      });
      expect(u.id, 'u-99');
    });

    test('numeric id is coerced to String', () {
      final u = User.fromJson(_base(overrides: {'id': 5}));
      expect(u.id, '5');
    });

    test('missing id → empty string fallback', () {
      final u = User.fromJson({
        'name': 'A',
        'email': 'a@b.com',
        'role': 'guru',
      });
      expect(u.id, '');
    });
  });

  // ---------------------------------------------------------------------------
  // name normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — name field', () {
    test('reads "name" directly', () {
      final u = User.fromJson(_base(overrides: {'name': 'Siti Rahayu'}));
      expect(u.name, 'Siti Rahayu');
    });

    test('falls back to "nama"', () {
      final u = User.fromJson({
        'id': 'u-1',
        'nama': 'Pak Budi',
        'email': 'budi@s.id',
        'role': 'guru',
      });
      expect(u.name, 'Pak Budi');
    });

    test('missing name → defaults to "User"', () {
      final u = User.fromJson({'id': '1', 'email': 'a@b.com', 'role': 'guru'});
      expect(u.name, 'User');
    });
  });

  // ---------------------------------------------------------------------------
  // role normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — role field', () {
    test('reads "role" directly', () {
      final u = User.fromJson(_base(overrides: {'role': 'admin'}));
      expect(u.role, 'admin');
    });

    test('falls back to "peran"', () {
      final u = User.fromJson({
        'id': '1',
        'name': 'A',
        'email': 'a@b.com',
        'peran': 'wali',
      });
      expect(u.role, 'wali');
    });

    test('missing role → empty string', () {
      final u = User.fromJson({'id': '1', 'name': 'A', 'email': 'a@b.com'});
      expect(u.role, '');
    });

    for (final role in ['guru', 'wali', 'siswa', 'admin', 'staff']) {
      test('preserves role "$role"', () {
        final u = User.fromJson(_base(overrides: {'role': role}));
        expect(u.role, role);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // schoolId normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — schoolId field', () {
    test('reads "school_id" directly', () {
      final u = User.fromJson(_base(overrides: {'school_id': 'sch-5'}));
      expect(u.schoolId, 'sch-5');
    });

    test('falls back to "sekolah_id"', () {
      final u = User.fromJson(_base(overrides: {'sekolah_id': 'sch-7'}));
      expect(u.schoolId, 'sch-7');
    });

    test('numeric school_id coerced to String', () {
      final u = User.fromJson(_base(overrides: {'school_id': 3}));
      expect(u.schoolId, '3');
    });

    test('is null when absent', () {
      final u = User.fromJson(_base());
      expect(u.schoolId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // schoolName normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — schoolName field', () {
    test('reads "school_name" directly', () {
      final u = User.fromJson(
        _base(overrides: {'school_name': 'SMP Negeri 1'}),
      );
      expect(u.schoolName, 'SMP Negeri 1');
    });

    test('falls back to "nama_sekolah"', () {
      final u = User.fromJson(
        _base(overrides: {'nama_sekolah': 'SMA Negeri 2'}),
      );
      expect(u.schoolName, 'SMA Negeri 2');
    });

    test('is null when absent', () {
      final u = User.fromJson(_base());
      expect(u.schoolName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // profilePictureUrl normalisation
  // ---------------------------------------------------------------------------
  group('User.fromJson — profilePictureUrl field', () {
    test('reads "profile_picture_url" directly', () {
      final u = User.fromJson(
        _base(
          overrides: {'profile_picture_url': 'https://cdn.example.com/pic.jpg'},
        ),
      );
      expect(u.profilePictureUrl, 'https://cdn.example.com/pic.jpg');
    });

    test('falls back to "foto_profil"', () {
      final u = User.fromJson(
        _base(overrides: {'foto_profil': 'https://cdn.example.com/foto.jpg'}),
      );
      expect(u.profilePictureUrl, 'https://cdn.example.com/foto.jpg');
    });

    test('is null when absent', () {
      final u = User.fromJson(_base());
      expect(u.profilePictureUrl, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Realistic API payloads
  // ---------------------------------------------------------------------------
  group('User.fromJson — realistic payloads', () {
    test('Indonesian-keyed teacher payload', () {
      final u = User.fromJson({
        'id': 42,
        'nama': 'Pak Dodi Susanto',
        'email': 'dodi@sekolah.id',
        'peran': 'guru',
        'sekolah_id': 7,
        'nama_sekolah': 'SMP Merdeka',
        'foto_profil': 'https://img.example.com/dodi.jpg',
      });
      expect(u.id, '42');
      expect(u.name, 'Pak Dodi Susanto');
      expect(u.role, 'guru');
      expect(u.schoolId, '7');
      expect(u.schoolName, 'SMP Merdeka');
      expect(u.profilePictureUrl, 'https://img.example.com/dodi.jpg');
    });

    test('English-keyed parent payload', () {
      final u = User.fromJson({
        'id': 'u-wali-3',
        'name': 'Ibu Kartini',
        'email': 'kartini@parent.id',
        'role': 'wali',
        'school_id': 'sch-1',
        'school_name': 'SD Harapan',
      });
      expect(u.name, 'Ibu Kartini');
      expect(u.role, 'wali');
      expect(u.schoolName, 'SD Harapan');
    });

    test('minimal payload with only required fields', () {
      final u = User.fromJson({'id': '1', 'email': 'x@y.com', 'role': 'siswa'});
      expect(u.name, 'User'); // default
      expect(u.schoolId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Freezed equality
  // ---------------------------------------------------------------------------
  group('User.fromJson — Freezed equality', () {
    test('two identical fromJson calls produce equal objects', () {
      final u1 = User.fromJson(_base());
      final u2 = User.fromJson(_base());
      expect(u1, equals(u2));
    });

    test('different roles produce non-equal objects', () {
      final u1 = User.fromJson(_base(overrides: {'role': 'guru'}));
      final u2 = User.fromJson(_base(overrides: {'role': 'admin'}));
      expect(u1, isNot(equals(u2)));
    });
  });
}
