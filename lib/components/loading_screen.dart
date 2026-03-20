// Full-screen loading indicator shown while data is being fetched.
//
// Like a Vue `<LoadingOverlay>` component or a Blade view with a centered
// spinner that you show with `v-if="isLoading"`. Displays a circular
// progress indicator inside a gradient circle with an optional message.
import 'package:flutter/material.dart';

/// A full-screen loading widget with a spinner and message.
///
/// Like a Vue `<LoadingScreen>` component shown with `v-if="isLoading"`.
///
/// Props (parameters):
/// - [message] - loading text displayed below the spinner (defaults to 'Memuat data...')
///
/// Used as the body of a Scaffold while API data is being loaded.
class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({super.key, this.message = 'Memuat data...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4361EE),
                    Color(0xFF4361EE).withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}