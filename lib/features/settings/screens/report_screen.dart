// Reports placeholder screen for the admin panel.
//
// Like `pages/admin/reports.vue` in a Vue app - a simple placeholder page
// for the reports feature. Currently shows a static label; will be expanded
// with actual report functionality later.
import 'package:flutter/material.dart';

/// Placeholder screen for the "Laporan" (Reports) feature.
///
/// This is a [StatelessWidget] - like a Vue component with no reactive data
/// (`data()` returns nothing). It only renders static content.
/// Unlike [StatefulWidget], it has no `mounted()` or local state.
class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  /// The build method - like Vue's `<template>`. Renders a simple centered text.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Laporan')),
      body: Center(child: Text('Fitur Laporan')),
    );
  }
}