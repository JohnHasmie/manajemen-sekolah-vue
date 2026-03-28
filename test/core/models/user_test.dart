import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses normal response with English fields', () {
      final json = {
        'id': 'u1',
        'name': 'John Doe',
        'email': 'john@example.com',
        'role': 'guru',
        'school_id': 's1',
        'school_name': 'Green School',
        'profile_picture_url': 'https://example.com/photo.jpg',
      };

      final user = User.fromJson(json);

      expect(user.id, 'u1');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.role, 'guru');
      expect(user.schoolId, 's1');
      expect(user.schoolName, 'Green School');
      expect(user.profilePictureUrl, 'https://example.com/photo.jpg');
    });

    test('handles Indonesian aliases (nama, sekolah_id, foto_profil)', () {
      final json = {
        'id': 'u2',
        'nama': 'Budi Santoso',
        'email': 'budi@example.com',
        'role': 'siswa',
        'sekolah_id': 's2',
        'nama_sekolah': 'SD Merdeka',
        'foto_profil': 'https://example.com/budi.jpg',
      };

      final user = User.fromJson(json);

      expect(user.name, 'Budi Santoso');
      expect(user.schoolId, 's2');
      expect(user.schoolName, 'SD Merdeka');
      expect(user.profilePictureUrl, 'https://example.com/budi.jpg');
    });
  });

  group('User.toJson', () {
    test('produces correct snake_case keys (English)', () {
      const user = User(
        id: 'u1',
        name: 'John Doe',
        email: 'john@example.com',
        role: 'admin',
        schoolId: 's1',
        schoolName: 'Green School',
        profilePictureUrl: 'https://example.com/photo.jpg',
      );

      final json = user.toJson();

      expect(json['id'], 'u1');
      expect(json['name'], 'John Doe');
      expect(json['school_id'], 's1');
      expect(json['profile_picture_url'], 'https://example.com/photo.jpg');
    });
  });

  group('User round-trip', () {
    test('toJson then fromJson preserves all fields', () {
      const original = User(
        id: 'u-rt',
        name: 'Round Trip',
        email: 'rt@example.com',
        role: 'guru',
        schoolId: 's-rt',
      );

      final json = original.toJson();
      final restored = User.fromJson(json);

      expect(restored, original);
    });
  });
}
