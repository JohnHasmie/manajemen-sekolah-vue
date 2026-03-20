// Administration dashboard screen for school staff.
// Like `pages/staff/Administration.vue` in a Vue app.
//
// This is a simple StatelessWidget (no local state needed) -- similar to a
// Vue component that only has a `<template>` and no `data()` or methods that
// mutate state.  In Laravel terms, think of it as a Blade view with no
// controller logic -- it just renders a grid of navigation cards.
import 'package:flutter/material.dart';

/// Displays a grid of administrative feature cards (incoming mail, outgoing
/// mail, documents, archives, diplomas, certificates).
///
/// This is a StatelessWidget because it has no mutable state.
/// In Vue terms, this is like a pure presentational component with only
/// `props` and `<template>` -- no `data()` or `methods` that change state.
class AdministrasiScreen extends StatelessWidget {
  const AdministrasiScreen({super.key});

  /// Builds the main scaffold with an AppBar and a 2-column grid of admin cards.
  /// Like the `<template>` section of a Vue SFC (Single File Component).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Administrasi')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16),
        children: [
          _buildAdminCard('Surat Masuk', Icons.mail_outline, () {}),
          _buildAdminCard('Surat Keluar', Icons.send, () {}),
          _buildAdminCard('Dokumen', Icons.folder, () {}),
          _buildAdminCard('Arsip', Icons.archive, () {}),
          _buildAdminCard('Ijazah', Icons.school, () {}),
          _buildAdminCard('Sertifikat', Icons.card_membership, () {}),
        ],
      ),
    );
  }

  /// Builds a single admin feature card with an icon and title.
  /// Like a reusable `<AdminCard>` Vue component rendered inside a `v-for`.
  Widget _buildAdminCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}