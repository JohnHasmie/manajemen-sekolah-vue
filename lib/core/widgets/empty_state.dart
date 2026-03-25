// Empty state placeholder component shown when a list has no data.
//
// Like a Vue component `<EmptyState>` or a Blade partial
// `@include('partials.empty-state')` shown with `@if($items->isEmpty())`.
// Displays a large icon, title, subtitle, and an optional action button.
import 'package:flutter/material.dart';

/// A centered empty state widget displayed when no data is available.
///
/// Like a Vue `<EmptyState>` component with props:
/// - [title] - main message (e.g., "No Students Found")
/// - [subtitle] - secondary description
/// - [icon] - large icon displayed in a circular gradient container
/// - [buttonText] / [onPressed] - optional CTA button (like a "Add First Item" link)
///
/// Used across list screens as a fallback when the API returns zero results.
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onPressed;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.people_outline,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4361EE).withValues(alpha: 0.1),
                  Color(0xFF4361EE).withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: Color(0xFF4361EE).withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}