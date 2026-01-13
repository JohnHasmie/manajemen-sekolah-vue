class Siswa {
  final String id;
  final String name;
  final String className;
  final String nis;
  final String alamat;
  final String nameParent;
  final String noTelepon;
  final String? classId;
  final String? studentClassId;

  Siswa({
    required this.id,
    required this.name,
    required this.className,
    required this.nis,
    required this.alamat,
    required this.nameParent,
    required this.noTelepon,
    this.classId,
    this.studentClassId,
  });

  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      className: json['kelas_nama'] ?? '',
      nis: json['student_number'] ?? '',
      alamat: json['address'] ?? '',
      nameParent: json['guardian_name'] ?? '',
      noTelepon: json['phone_number'] ?? '',
      classId: json['class_id'],
      studentClassId: json['student_class_id'],
    );
  }
}
