import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelRekapNilaiService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<void> exportRekapNilaiToExcel({
    required List<Map<String, dynamic>> tableData,
    required List<dynamic> chapters,
    required String className,
    required String subjectName,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final headers = await ApiService.getHeaders();

      final Map<String, dynamic> payload = {
        'tableData': tableData,
        'chapters': chapters,
        'className': className,
        'subjectName': subjectName,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/grade-recaps/export'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Get directory
        final Directory directory = await getApplicationDocumentsDirectory();

        String formattedSubject = subjectName.replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '_',
        );
        String formattedClass = className.replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '_',
        );
        final String filePath =
            '${directory.path}/Rekap_Nilai_${formattedClass}_${formattedSubject}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Save file
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Open the file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Grade Rekap exported successfully',
                'id': 'Rekap nilai berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMessage = 'Failed to export data';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export data: $e',
              'id': 'Gagal mengexport data: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
