// School correspondence / letter management screen for staff.
// Like `pages/staff/Correspondence.vue` in a Vue app.
//
// Displays incoming and outgoing letters with their status.
// Currently uses hardcoded data; in production this would call
// a Laravel `LetterController@index` API endpoint.
import 'package:flutter/material.dart';

/// Lists all school correspondence (incoming/outgoing letters) with status chips.
///
/// StatelessWidget with inline static data. In Vue this would be like having
/// the data defined directly inside `data() { return { surat: [...] } }`.
/// The `surat` list here is equivalent to a Vue component's reactive data property.
class CorrespondenceScreen extends StatelessWidget {
  /// Hardcoded sample letter data. In production, this would come from an API.
  /// Like `data() { return { surat: [...] } }` in a Vue component.
  final List<Map<String, dynamic>> surat = [
    {
      'judul': 'Surat Undangan Rapat Guru',
      'tanggal': '2024-01-15',
      'status': 'Terkirim',
      'jenis': 'Keluar',
    },
    {
      'judul': 'Surat Permohonan Izin Kegiatan',
      'tanggal': '2024-01-12',
      'status': 'Diterima',
      'jenis': 'Masuk',
    },
    {
      'judul': 'Surat Edaran Libur Semester',
      'tanggal': '2024-01-10',
      'status': 'Terkirim',
      'jenis': 'Keluar',
    },
  ];
  
  CorrespondenceScreen({super.key});

  /// Builds the letter list UI with a FAB for creating new letters.
  /// Like the `<template>` section of a Vue SFC with `v-for="item in surat"`.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Surat Menyurat')),
      body: ListView.builder(
        itemCount: surat.length,
        itemBuilder: (context, index) {
          final item = surat[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(
                item['jenis'] == 'Masuk' ? Icons.mail : Icons.send,
                color: item['jenis'] == 'Masuk' ? Colors.green : Colors.blue,
              ),
              title: Text(item['judul']),
              subtitle: Text('${item['tanggal']} - ${item['jenis']}'),
              trailing: Chip(
                label: Text(item['status']),
                backgroundColor: item['status'] == 'Terkirim'
                    ? Colors.blue[100]
                    : Colors.green[100],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}
