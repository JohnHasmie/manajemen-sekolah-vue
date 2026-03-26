// Student data listing screen for school staff.
// Like `pages/staff/StudentData.vue` in a Vue app.
//
// Currently uses dummy data (DataDummy.students) -- in production this would
// fetch from an API endpoint similar to a Laravel `StudentController@index`.
// This is a StatelessWidget because the data source is static dummy data.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/data/data_dummy.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Displays a scrollable list of all students with basic info (NIS, class, parent).
///
/// StatelessWidget -- no mutable state. In Vue terms this is a presentational
/// component that receives its data externally (here from [DataDummy]).
/// The [Student] model is like a Laravel Eloquent Model / TypeScript interface.
class StaffStudentDataScreen extends StatelessWidget {
  const StaffStudentDataScreen({super.key});

  /// Builds the Scaffold with a ListView of student cards.
  /// Like the `<template>` of a Vue SFC that uses `v-for` over the student list.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Data Siswa')),
      body: ListView.builder(
        itemCount: DataDummy.students.length,
        itemBuilder: (context, index) {
          final student = DataDummy.students[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: CircleAvatar(child: Text(student.name[0])),
              title: Text(student.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NIS: ${student.studentNumber}'),
                  Text('${AppLocalizations.classString.tr}: ${student.className}'),
                  Text('${languageProvider.getTranslatedText({'en': 'Guardian', 'id': 'Wali'})}: ${student.guardianName}'),
                  Text('${AppLocalizations.address.tr}: ${student.address}'),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.info),
                onPressed: () => _showDetailSiswa(context, student),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens a dialog showing full student details.
  /// Like calling `this.$modal.show('student-detail')` in Vue, or using
  /// a `<el-dialog>` / Bootstrap modal in a Vue component.
  void _showDetailSiswa(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${languageProvider.getTranslatedText({'en': 'Detail', 'id': 'Detail'})} ${student.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIS: ${student.studentNumber}'),
            Text('${AppLocalizations.classString.tr}: ${student.className}'),
            Text('${AppLocalizations.address.tr}: ${student.address}'),
            Text('${languageProvider.getTranslatedText({'en': 'Guardian Name', 'id': 'Nama Wali'})}: ${student.guardianName}'),
            Text('${AppLocalizations.phoneNumber.tr}: ${student.phoneNumber}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text(AppLocalizations.close.tr),
          ),
        ],
      ),
    );
  }
}
