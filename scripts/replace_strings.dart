// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int replacements = 0;

  for (final file in files) {
    String content = file.readAsStringSync();
    final String originalContent = content;

    // Add necessary import if not present and we replace something
    bool needsImport = false;

    // Map of text replacements
    // 'Raw string' : 'AppLocalizations.key.tr'
    final replaces = {
      "'Perbarui Data'": "AppLocalizations.updateData.tr",
      "\"Perbarui Data\"": "AppLocalizations.updateData.tr",
      "'Coba Lagi'": "AppLocalizations.tryAgain.tr",
      "\"Coba Lagi\"": "AppLocalizations.tryAgain.tr",
      "'Pilih Kelas'": "AppLocalizations.selectClass.tr",
      "\"Pilih Kelas\"": "AppLocalizations.selectClass.tr",
      "'Tidak ada data absensi untuk periode ini'": "AppLocalizations.noAttendanceData.tr",
      "'Semua Bulan'": "AppLocalizations.allMonths.tr",
      "'Semua Jenis'": "AppLocalizations.allTypes.tr",
      "'Transfer Bank'": "AppLocalizations.bankTransfer.tr",
      "'Kartu Kredit/Debit'": "AppLocalizations.creditCard.tr",
      "'Format tanggal: YYYY-MM-DD'": "AppLocalizations.dateFormatHint.tr",
    };

    replaces.forEach((oldText, newText) {
      final patternConst = RegExp(r'const\s+Text\(' + RegExp.escape(oldText) + r'\)');
      if (patternConst.hasMatch(content)) {
        content = content.replaceAll(patternConst, 'Text($newText)');
        needsImport = true;
      }

      final patternText = RegExp(r'Text\(' + RegExp.escape(oldText) + r'\)');
      if (patternText.hasMatch(content)) {
        content = content.replaceAll(patternText, 'Text($newText)');
        needsImport = true;
      }
      
      final patternSetText = RegExp(r'\.setText\(' + RegExp.escape(oldText) + r'\)');
      if (patternSetText.hasMatch(content)) {
        content = content.replaceAll(patternSetText, '.setText($newText)');
        needsImport = true;
      }
    });

    if (content != originalContent) {
      if (needsImport && !content.contains("import 'package:manajemensekolah/core/utils/language_utils.dart';")) {
        final int lastImportIndex = content.lastIndexOf(RegExp(r"import\s+['\x22].*['\x22];"));
        if (lastImportIndex != -1) {
          int endOfLine = content.indexOf('\n', lastImportIndex);
          if (endOfLine == -1) endOfLine = content.length;
          content = "${content.substring(0, endOfLine)}\nimport 'package:manajemensekolah/core/utils/language_utils.dart';${content.substring(endOfLine)}";
        } else {
          content = "import 'package:manajemensekolah/core/utils/language_utils.dart';\n$content";
        }
      }
      
      file.writeAsStringSync(content);
      replacements++;
      print('Updated: ${file.path}');
    }
  }

  print('Total files updated: $replacements');
}
