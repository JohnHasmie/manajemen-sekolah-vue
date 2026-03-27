// Service class for exporting RPP (lesson plan) documents to Word/PDF formats.
// Like a Laravel Service class (e.g., `App\Services\RppExportService`) that
// handles file generation and download logic, keeping it separate from the
// controller/screen. In Vue terms, this is like a utility module in
// `utils/rppExport.js` that the component imports and calls.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Handles exporting RPP content to Word (.docx) and PDF file formats.
///
/// This is a pure service class (no UI) -- like a Laravel Service or a
/// Vue composable/utility. It writes files to the device's temporary
/// directory and opens them with the system file viewer.
///
/// All methods are `static` -- no instance needed, similar to Laravel's
/// static helper methods or a Vue utility function.
class LessonPlanExportService {
  /// Exports RPP content as a Word-like HTML document and opens it.
  /// Like calling a Laravel queue job that generates a .docx file.
  static Future<void> exportToWord(String content, String fileName) async {
    try {
      // Format content for Word-like structure
      await Future.delayed(Duration(milliseconds: 100));
      final formattedContent = _formatForWord(content);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.docx');
      
      // For simulating a Word file, we create a text file with formatting
      await file.writeAsString(formattedContent);
      
      await OpenFile.open(file.path);
    } catch (e) {
      throw Exception('Gagal export ke Word: $e');
    }
  }

  /// Exports RPP content as a PDF file and opens it.
  /// Currently a placeholder -- in production would use a proper PDF library.
  static Future<void> exportToPDF(String content, String fileName) async {
    try {
      // Better PDF export implementation
      await Future.delayed(Duration(milliseconds: 100));
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.pdf');
      
      // For now, we create a text file as a simulation
      // In production, use a PDF generation library like pdf or printing
      await file.writeAsString('PDF Export: $content');
      
      await OpenFile.open(file.path);
    } catch (e) {
      throw Exception('Gagal export ke PDF: $e');
    }
  }

  /// Converts plain text content into a basic HTML document for Word rendering.
  /// Like a Laravel Blade template that wraps content in HTML structure.
  static String _formatForWord(String content) {
    final buffer = StringBuffer();
    final lines = content.split('\n');
    
    for (String line in lines) {
      if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
        buffer.writeln('<h1 style="text-align: center; color: #4F46E5;">$line</h1>');
      } else if (line.startsWith('A.') || line.startsWith('B.') || line.startsWith('C.')) {
        buffer.writeln('<h2 style="color: #4F46E5;">$line</h2>');
      } else if (line.startsWith('|')) {
        buffer.writeln('<table border="1"><tr>${_formatTableRow(line)}</tr></table>');
      } else if (line.startsWith('•')) {
        buffer.writeln('<li>$line</li>');
      } else {
        buffer.writeln('<p>$line</p>');
      }
    }
    
    return '''
<html>
<head>
<meta charset="UTF-8">
<title>RPP Document</title>
</head>
<body>
${buffer.toString()}
</body>
</html>
''';
  }

  static String _formatTableRow(String line) {
    final cells = line.split('|').where((cell) => cell.trim().isNotEmpty).toList();
    return cells.map((cell) => '<td style="padding: 8px; border: 1px solid #ccc;">${cell.trim()}</td>').join();
  }
}