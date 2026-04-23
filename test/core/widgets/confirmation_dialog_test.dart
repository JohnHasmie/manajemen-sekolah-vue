// Tests for the ConfirmationDialog widget.
//
// The dialog uses AppLocalizations.cancel.tr / AppLocalizations.delete.tr
// which resolve via the global `languageProvider` singleton (default = 'id'),
// so the Indonesian labels 'Batal' and 'Hapus' are expected.
// The dialog calls AppNavigator.pop which delegates to context.pop (go_router)
// or Navigator.pop. Wrapped in MaterialApp so Navigator is available.
// No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';

// ConfirmationDialog buttons call AppNavigator.pop → context.pop (go_router),
// so tests must be wrapped in a GoRouter context.
Future<bool?> _showDialog(
  WidgetTester tester, {
  String title = 'Delete Record',
  String content = 'Are you sure?',
  String? confirmText,
  Color confirmColor = Colors.red,
}) async {
  bool? result;

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: ctx,
                builder: (_) => ConfirmationDialog(
                  title: title,
                  content: content,
                  confirmText: confirmText,
                  confirmColor: confirmColor,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();

  // Open the dialog.
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return result;
}

void main() {
  group('ConfirmationDialog', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await _showDialog(tester);
      expect(find.byType(ConfirmationDialog), findsOneWidget);
    });

    testWidgets('displays the title text', (WidgetTester tester) async {
      await _showDialog(tester, title: 'Delete Student');
      expect(find.text('Delete Student'), findsOneWidget);
    });

    testWidgets('displays the content text', (WidgetTester tester) async {
      await _showDialog(tester, content: 'This action cannot be undone.');
      expect(find.text('This action cannot be undone.'), findsOneWidget);
    });

    testWidgets('shows warning icon in the header', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.warning_rounded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows custom confirmText when provided', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester, confirmText: 'Yes, Remove');
      expect(find.text('Yes, Remove'), findsOneWidget);
    });

    testWidgets('cancel button label resolves from translations', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester);
      // Default language is Indonesian → 'Batal'
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('tapping cancel closes the dialog', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('tapping confirm closes the dialog', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester);
      // Default confirm label in Indonesian is 'Hapus'.
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsNothing);
    });
  });
}
