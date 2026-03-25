// Dashboard card builder function for the main dashboard grid.
//
// Like a Blade partial `@include('dashboard.card')` or a simple Vue
// `<DashboardCard>` component rendered in a CSS grid layout.
// This is a top-level function (not a class) -- similar to a Laravel
// helper function in `helpers.php`.
import 'package:flutter/material.dart';

/// Builds a simple dashboard card widget with an icon, title, and tap handler.
///
/// This is a standalone builder function rather than a widget class.
/// In Vue terms, think of it as a render function or a functional component:
/// ```vue
/// <DashboardCard :title="title" :icon="icon" @click="onTap" :color="color" />
/// ```
///
/// Parameters map to Vue props:
/// - [title] - card label text
/// - [icon] - Material icon displayed prominently
/// - [onTap] - navigation callback (like `@click` / `$router.push`)
/// - [color] - icon tint color
Widget buildDashboardCard(String title, IconData icon, VoidCallback onTap, Color color) {
  return Card(
    elevation: 4,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: color),
          SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}