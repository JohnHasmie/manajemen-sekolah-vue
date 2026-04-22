#!/usr/bin/env dart
// ═══════════════════════════════════════════════════════════════
// Kamiledu Code Quality Check
// ═══════════════════════════════════════════════════════════════
//
// A lightweight script that enforces the project's coding
// standards by scanning Dart files for violations:
//
//   • Max 400 lines per file
//   • Max 40 lines per method/function
//   • Max 80 characters per line
//
// Usage:
//   dart run tool/code_quality_check.dart          # check lib/
//   dart run tool/code_quality_check.dart lib/core  # check specific dir
//   dart run tool/code_quality_check.dart --fix     # show fix suggestions
//
// Exit codes:
//   0 — all checks passed
//   1 — violations found
//
// This script works standalone (no dependencies beyond dart:io)
// and complements the dart_code_linter analyzer plugin.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';

// ─── Thresholds (match analysis_options.yaml) ────────────────
const int maxFileLines = 400;
const int maxMethodLines = 40;
const int maxLineLength = 80;

// ─── ANSI Colors ─────────────────────────────────────────────
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _green = '\x1B[32m';
const _cyan = '\x1B[36m';
const _dim = '\x1B[2m';
const _bold = '\x1B[1m';
const _reset = '\x1B[0m';

class Violation {
  final String file;
  final String type;
  final String message;
  final int? line;
  final String? suggestion;

  Violation({
    required this.file,
    required this.type,
    required this.message,
    this.line,
    this.suggestion,
  });
}

void main(List<String> args) {
  final showFix = args.contains('--fix');
  final targetPaths = args.where((a) => !a.startsWith('-')).toList();
  final scanPath = targetPaths.isNotEmpty ? targetPaths.first : 'lib';

  final dir = Directory(scanPath);
  if (!dir.existsSync()) {
    stderr.writeln('${_red}Error: Directory "$scanPath" not found.$_reset');
    exit(1);
  }

  stdout.writeln(
    '$_bold$_cyan╔══════════════════════════════════════════╗$_reset',
  );
  stdout.writeln(
    '$_bold$_cyan║   Kamiledu Code Quality Check            ║$_reset',
  );
  stdout.writeln(
    '$_bold$_cyan╚══════════════════════════════════════════╝$_reset',
  );
  stdout.writeln('${_dim}Scanning: $scanPath$_reset');
  stdout.writeln(
    '${_dim}Rules: file ≤$maxFileLines lines, '
    'method ≤$maxMethodLines lines, '
    'line ≤$maxLineLength chars$_reset',
  );
  stdout.writeln();

  final violations = <Violation>[];
  var filesScanned = 0;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    // Skip generated files
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;

    filesScanned++;
    final relativePath = entity.path.replaceFirst(RegExp('^.*/lib/'), 'lib/');
    final lines = entity.readAsLinesSync();

    // ── Check 1: File length ──
    if (lines.length > maxFileLines) {
      violations.add(
        Violation(
          file: relativePath,
          type: 'FILE_TOO_LONG',
          message: '${lines.length} lines (max $maxFileLines)',
          suggestion: showFix
              ? 'Split into smaller widgets/mixins/helpers. '
                    'Extract large build() sections into _build*() methods '
                    'in separate files.'
              : null,
        ),
      );
    }

    // ── Check 2: Method/function length ──
    _checkMethodLengths(relativePath, lines, violations, showFix);

    // ── Check 3: Line length ──
    _checkLineLengths(relativePath, lines, violations);
  }

  // ─── Report ────────────────────────────────────────────────
  _printReport(violations, filesScanned, showFix);
  exit(violations.isEmpty ? 0 : 1);
}

/// Scans for method/function declarations and checks body length.
void _checkMethodLengths(
  String file,
  List<String> lines,
  List<Violation> violations,
  bool showFix,
) {
  // Pattern matches: method declarations, functions, named constructors
  final methodPattern = RegExp(
    r'^\s*'
    r'(?:@override\s+)?'
    r'(?:static\s+)?'
    r'(?:Future<[\w<>?,\s]+>\s+|'
    r'Stream<[\w<>?,\s]+>\s+|'
    r'[\w<>?,\s]+\s+)?'
    r'(?:get\s+)?'
    r'(\w+)\s*'
    r'(?:<[\w,\s]+>)?'
    r'\([^)]*\)\s*'
    r'(?:async\s*)?'
    r'\{?\s*$',
  );

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimLeft();

    // Skip comments and empty lines
    if (line.startsWith('//') || line.startsWith('/*')) continue;
    if (line.isEmpty) continue;

    // Look for method-like declarations
    final match = methodPattern.firstMatch(lines[i]);
    if (match == null) continue;

    final methodName = match.group(1) ?? '?';

    // Skip one-liners (=> expressions on same line)
    if (lines[i].contains('=>') && !lines[i].trimRight().endsWith('{')) {
      continue;
    }

    // Find the opening brace
    var braceStart = i;
    if (!lines[i].contains('{')) {
      // Look ahead for the brace (max 3 lines for multi-line params)
      var found = false;
      for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
        if (lines[j].contains('{')) {
          braceStart = j;
          found = true;
          break;
        }
      }
      if (!found) continue;
    }

    // Count lines in the method body
    final bodyStart = braceStart;
    var depth = 0;
    var bodyLineCount = 0;

    for (var j = bodyStart; j < lines.length; j++) {
      for (final ch in lines[j].runes) {
        if (ch == 0x7B) depth++; // {
        if (ch == 0x7D) depth--; // }
      }
      if (j > bodyStart) {
        final trimmed = lines[j].trim();
        // Count non-empty, non-comment lines
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('//') &&
            !trimmed.startsWith('/*') &&
            !trimmed.startsWith('*')) {
          bodyLineCount++;
        }
      }
      if (depth == 0 && j > bodyStart) break;
    }

    if (bodyLineCount > maxMethodLines) {
      violations.add(
        Violation(
          file: file,
          type: 'METHOD_TOO_LONG',
          message:
              '$methodName() has $bodyLineCount lines (max $maxMethodLines)',
          line: i + 1,
          suggestion: showFix
              ? 'Break into smaller helper methods. '
                    'Each method should do one thing only.'
              : null,
        ),
      );
    }
  }
}

/// Checks for lines exceeding the max character length.
/// Only reports the count per file (not every single line).
void _checkLineLengths(
  String file,
  List<String> lines,
  List<Violation> violations,
) {
  var longLineCount = 0;
  int? firstLongLine;

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].length > maxLineLength) {
      longLineCount++;
      firstLongLine ??= i + 1;
    }
  }

  if (longLineCount > 0) {
    violations.add(
      Violation(
        file: file,
        type: 'LONG_LINES',
        message:
            '$longLineCount lines exceed $maxLineLength chars '
            '(first at line $firstLongLine)',
        line: firstLongLine,
      ),
    );
  }
}

/// Prints a formatted report of all violations.
void _printReport(List<Violation> violations, int filesScanned, bool showFix) {
  if (violations.isEmpty) {
    stdout.writeln(
      '$_green$_bold✓ All $filesScanned files pass '
      'code quality checks!$_reset',
    );
    return;
  }

  // Group by file
  final byFile = <String, List<Violation>>{};
  for (final v in violations) {
    byFile.putIfAbsent(v.file, () => []).add(v);
  }

  // Count by type
  final fileTooLong = violations.where((v) => v.type == 'FILE_TOO_LONG').length;
  final methodTooLong = violations
      .where((v) => v.type == 'METHOD_TOO_LONG')
      .length;
  final longLines = violations.where((v) => v.type == 'LONG_LINES').length;

  stdout.writeln(
    '$_red$_bold✗ Found ${violations.length} violation(s) '
    'in ${byFile.length} file(s)$_reset',
  );
  stdout.writeln();

  for (final entry in byFile.entries) {
    stdout.writeln('$_bold${entry.key}$_reset');
    for (final v in entry.value) {
      final lineInfo = v.line != null ? ':${v.line}' : '';
      final icon = v.type == 'FILE_TOO_LONG'
          ? '📄'
          : v.type == 'METHOD_TOO_LONG'
          ? '📏'
          : '↔️';
      stdout.writeln(
        '  $icon $_yellow${v.message}$_reset'
        '$_dim$lineInfo$_reset',
      );
      if (v.suggestion != null) {
        stdout.writeln('     $_dim💡 ${v.suggestion}$_reset');
      }
    }
    stdout.writeln();
  }

  // Summary
  stdout.writeln('$_bold── Summary ──$_reset');
  stdout.writeln('  Files scanned:    $filesScanned');
  if (fileTooLong > 0) {
    stdout.writeln(
      '  ${_red}Files too long:   $fileTooLong '
      '(max $maxFileLines lines)$_reset',
    );
  }
  if (methodTooLong > 0) {
    stdout.writeln(
      '  ${_red}Methods too long: $methodTooLong '
      '(max $maxMethodLines lines)$_reset',
    );
  }
  if (longLines > 0) {
    stdout.writeln(
      '  ${_yellow}Long line files:  $longLines '
      '(max $maxLineLength chars)$_reset',
    );
  }
}
