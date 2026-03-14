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
      className: json['kelas_nama'] ?? json['class']?['name'] ?? '',
      nis: json['student_number'] ?? '',
      alamat: json['address'] ?? '',
      nameParent: json['guardian_name'] ?? '',
      noTelepon: json['phone_number'] ?? '',
      classId: json['class_id'],
      studentClassId: json['student_class_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kelas_nama': className,
      'student_number': nis,
      'address': alamat,
      'guardian_name': nameParent,
      'phone_number': noTelepon,
      'class_id': classId,
      'student_class_id': studentClassId,
    };
  }
}
