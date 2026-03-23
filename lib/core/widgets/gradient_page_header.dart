// Reusable gradient page header with back button, title, and optional slots.
//
// Like a Vue `<PageHeader>` layout component or a Blade partial
// `@include('layouts.page-header')`. Provides a consistent gradient header
// across all management screens, with optional search bar and filter chips
// injected as child widgets (similar to Vue's named slots).
import 'package:flutter/material.dart';

/// A gradient header bar displayed at the top of management screens.
///
/// Like a Vue `<PageHeader>` component with named slots:
/// - [title] / [subtitle] - header text (like `<template #title>`)
/// - [primaryColor] - gradient base color
/// - [onBackPressed] - back navigation callback (auto-shows if Navigator can pop)
/// - [actionMenu] - optional trailing widget, like a popup menu (slot `#actions`)
/// - [searchBar] - optional search bar widget below the header (slot `#search`)
/// - [filterChips] - optional filter chips below search (slot `#filters`)
///
/// Handles safe area padding automatically (like a Blade `@section('header')`).
class GradientPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback? onBackPressed;
  final Widget? actionMenu;
  final Widget? searchBar;
  final Widget? filterChips;

  const GradientPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    this.onBackPressed,
    this.actionMenu,
    this.searchBar,
    this.filterChips,
  });

  /// Builds the gradient header with back button, title/subtitle row,
  /// and optional search bar and filter chip sections.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back button
              if (onBackPressed != null || Navigator.canPop(context)) ...[
                GestureDetector(
                  onTap: onBackPressed ?? () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Action menu
              if (actionMenu != null) actionMenu!,
            ],
          ),

          if (searchBar != null) ...[const SizedBox(height: 16), searchBar!],

          if (filterChips != null) ...[
            const SizedBox(height: 12),
            filterChips!,
          ],
        ],
      ),
    );
  }
}
