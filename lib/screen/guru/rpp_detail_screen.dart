import 'dart:io';

import 'package:flutter/foundation.dart'; // Required for kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/screen/guru/rpp_ai_result_screen.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RPPDetailPage extends StatefulWidget {
  final Map<String, dynamic> rppData;
  final bool isNew;

  const RPPDetailPage({super.key, required this.rppData, this.isNew = false});

  @override
  RPPDetailPageState createState() => RPPDetailPageState();
}

class RPPDetailPageState extends State<RPPDetailPage> {
  bool _isSaving = false;
  bool _isEditing = false;
  String _editedContent = '';

  bool get _hasAiAdditionalData {
    const aiKeys = [
      'core_competence',
      'basic_competence',
      'indicator',
      'learning_objective',
      'main_material',
      'learning_method',
      'media_tools',
      'learning_source',
      'learning_activities',
      'assessment',
      // Metadata yang biasanya disimpan dengan AI generation
      'ai_model_used',
      'ai_tokens_used',
      'ai_generated',
    ];

    return aiKeys.any((key) {
      final value = widget.rppData[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  String get _teacherId {
    return (widget.rppData['guru_id'] ?? widget.rppData['teacher_id'] ?? '')
        .toString();
  }

  void _openAiRppScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RppAiResultScreen(
          rppData: widget.rppData,
          teacherId: _teacherId,
          onSaved: () {
            // Jika ingin refresh halaman setelah menyimpan, bisa tambahkan logika di sini.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('RPP AI berhasil disimpan')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _editedContent = _formatRPPContent();
  }

  String _formatRPPContent() {
    final buffer = StringBuffer();

    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = widget.rppData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return defaultValue;
    }

    final title = getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = getField([
      'mata_pelajaran_nama',
      'subject_name',
    ]);
    final className = getField(['kelas_nama', 'class_name']);
    final semester = getField(['semester']);
    final academicYear = getField(['tahun_ajaran', 'academic_year']);
    final teacherName = getField(['guru_nama', 'teacher_name']);
    final status = getField(['status']);

    // Header fields yang mungkin ada dari AI generation atau input manual
    final unit = getField(['satuan_pendidikan', 'education_unit']);
    final theme = getField(['tema', 'theme']);
    final subTheme = getField(['sub_tema', 'sub_theme']);
    final sequence = getField(['pembelajaran_ke', 'learning_sequence']);
    final timeAllocation = getField(['alokasi_waktu', 'time_allocation']);

    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln();

    // Informasi Header dari database
    buffer.writeln('Judul\t\t\t: $title');
    if (subjectName.isNotEmpty) {
      buffer.writeln('Mata Pelajaran\t: $subjectName');
    }
    if (className.isNotEmpty) {
      buffer.writeln('Kelas\t\t\t: $className');
    }
    if (semester.isNotEmpty) {
      buffer.writeln('Semester\t\t: $semester');
    }
    if (academicYear.isNotEmpty) {
      buffer.writeln('Tahun Ajaran\t\t: $academicYear');
    }
    if (teacherName.isNotEmpty) {
      buffer.writeln('Guru\t\t\t: $teacherName');
    }
    if (status.isNotEmpty) {
      buffer.writeln('Status\t\t\t: $status');
    }

    // Header tambahan (dari AI generation atau input manual)
    if (unit.isNotEmpty) {
      buffer.writeln('Satuan Pendidikan\t: $unit');
    }
    if (theme.isNotEmpty) {
      buffer.writeln('Tema\t\t\t: $theme');
    }
    if (subTheme.isNotEmpty) {
      buffer.writeln('Sub Tema\t\t: $subTheme');
    }
    if (sequence.isNotEmpty) {
      buffer.writeln('Pembelajaran ke\t: $sequence');
    }
    if (timeAllocation.isNotEmpty) {
      buffer.writeln('Alokasi waktu\t: $timeAllocation');
    }
    buffer.writeln();

    // Cek apakah RPP hasil genrasi AI (format 10 komponen API)
    final bool isAi =
        widget.rppData['ai_generated'] == true ||
        widget.rppData['is_ai_generated'] == true;

    // Kompetensi Inti & Kompetensi Dasar (jika tersedia)
    final String kompetensiInti = getField([
      'kompetensi_inti',
      'kompetensiInti',
      'ki',
      'core_competence',
    ]);
    final String kompetensiDasar = getField([
      'kompetensi_dasar',
      'kompetensiDasar',
      'kd',
      'basic_competence',
    ]);
    final String indikator = getField(['indikator', 'indicator']);

    int sectionIndex = 1;
    if (kompetensiInti.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI INTI (KI)',
      );
      buffer.writeln(_stripHtml(kompetensiInti));
      buffer.writeln();
      sectionIndex++;
    }

    if (kompetensiDasar.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI DASAR (KD)',
      );
      buffer.writeln(_stripHtml(kompetensiDasar));
      buffer.writeln();
      sectionIndex++;
    }

    if (indikator.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. INDIKATOR');
      buffer.writeln(_stripHtml(indikator));
      buffer.writeln();
      sectionIndex++;
    }

    // TUJUAN PEMBELAJARAN
    final tujuan = getField([
      'learning_objective',
      'tujuan_pembelajaran',
      'learning_objectives',
    ]);

    if (tujuan.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. TUJUAN PEMBELAJARAN',
      );
      sectionIndex++;
      if (isAi) {
        buffer.writeln(_stripHtml(tujuan));
      } else {
        final tujuanLines = tujuan.split('\n');
        for (int i = 0; i < tujuanLines.length; i++) {
          if (tujuanLines[i].trim().isNotEmpty) {
            buffer.writeln('${i + 1}. ${tujuanLines[i].trim()}');
          }
        }
      }
      buffer.writeln();
    }

    // KEGIATAN PEMBELAJARAN
    final kegiatanPendahuluan = getField([
      'kegiatan_pendahuluan',
      'preliminary_activities',
    ]);
    final kegiatanInti = getField([
      'learning_activities',
      'kegiatan_inti',
      'core_activities',
    ]);
    final kegiatanPenutup = getField([
      'kegiatan_penutup',
      'closing_activities',
    ]);

    if (kegiatanInti.isNotEmpty ||
        kegiatanPendahuluan.isNotEmpty ||
        kegiatanPenutup.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KEGIATAN PEMBELAJARAN',
      );
      buffer.writeln();
      sectionIndex++;

      if (kegiatanPendahuluan.isEmpty && kegiatanPenutup.isEmpty) {
        // Data dari DB (learning_activities) atau AI - 1 field saja
        buffer.writeln(_stripHtml(kegiatanInti));
      } else {
        // Data terpisah (pendahuluan, inti, penutup)
        if (kegiatanPendahuluan.isNotEmpty) {
          final pendahuluanTime = getField(['waktu_pendahuluan']);
          buffer.writeln(
            'Kegiatan Pendahuluan${pendahuluanTime.isNotEmpty ? ' ($pendahuluanTime menit)' : ''}',
          );
          for (var line in kegiatanPendahuluan.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
          buffer.writeln();
        }

        if (kegiatanInti.isNotEmpty) {
          final intiTime = getField(['waktu_inti']);
          buffer.writeln(
            'Kegiatan Inti${intiTime.isNotEmpty ? ' ($intiTime menit)' : ''}',
          );
          for (var line in kegiatanInti.split('\n')) {
            if (line.trim().isNotEmpty) {
              if (line.trim().startsWith('A.') ||
                  line.trim().startsWith('B.') ||
                  line.trim().startsWith('C.')) {
                buffer.writeln(line.trim());
              } else {
                buffer.writeln('• ${line.trim()}');
              }
            }
          }
          buffer.writeln();
        }

        if (kegiatanPenutup.isNotEmpty) {
          final penutupTime = getField(['waktu_penutup']);
          buffer.writeln(
            'Kegiatan Penutup${penutupTime.isNotEmpty ? ' ($penutupTime menit)' : ''}',
          );
          for (var line in kegiatanPenutup.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
        }
      }
      buffer.writeln();
    }

    // PENILAIAN
    final assessment = getField(['assessment', 'penilaian']);
    if (assessment.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. PENILAIAN (ASESMEN)',
      );
      if (isAi) {
        buffer.writeln(_stripHtml(assessment));
      } else {
        buffer.writeln(assessment);
      }
      buffer.writeln();
    }

    // Materi dan Sumber Belajar (jika tersedia)
    final String mainMaterial = getField(['main_material']);
    final String learningMethod = getField(['learning_method']);
    final String mediaTools = getField(['media_tools']);
    final String learningSource = getField(['learning_source']);

    if (mainMaterial.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. MATERI POKOK',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(mainMaterial));
      buffer.writeln();
    }

    if (learningMethod.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. METODE PEMBELAJARAN',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(learningMethod));
      buffer.writeln();
    }

    if (mediaTools.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. MEDIA / ALAT',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(mediaTools));
      buffer.writeln();
    }

    if (learningSource.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. SUMBER BELAJAR',
      );
      sectionIndex++;
      buffer.writeln(_stripHtml(learningSource));
      buffer.writeln();
    }

    // Tanda Tangan
    buffer.writeln('Mengetahui');
    buffer.writeln();
    buffer.writeln('Kepala Sekolah');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');
    buffer.writeln();
    buffer.writeln('Guru Mata Pelajaran');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');

    if (widget.rppData['ai_generated'] == true ||
        widget.rppData['is_ai_generated'] == true) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*RPP ini digenerate secara otomatis menggunakan AI*');
    }

    return buffer.toString();
  }

  // Simple HTML stripper helper
  String _stripHtml(String html) {
    if (html.isEmpty) return '';

    // Replace list tags with newlines and bullets/numbers
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');

    int counter = 1;
    while (text.contains('<li>')) {
      if (html.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');

    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');

    // Remove all remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Clean up extra whitespace and decode common entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    // Remove consecutive empty lines (more than 2)
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  Future<void> _saveRPP() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Map data (falling back to known AI-generated key names if available)
      String fallback(List<String> keys) {
        for (final k in keys) {
          if (widget.rppData.containsKey(k) && widget.rppData[k] != null) {
            return widget.rppData[k].toString();
          }
        }
        return '';
      }

      await ApiSubjectService.saveRPP({
        'teacher_id': fallback(['teacher_id', 'guru_id']),
        'subject_id': fallback(['subject_id', 'mata_pelajaran_id']),
        'class_id': fallback(['class_id']),
        'title': fallback(['title', 'judul']),
        'semester': fallback(['semester']),
        'academic_year': fallback(['academic_year', 'tahun_ajaran']),
        'core_competence': fallback([
          'core_competence',
          'kompetensi_inti',
          'kompetensiInti',
          'ki',
        ]),
        'basic_competence': fallback([
          'basic_competence',
          'kompetensi_dasar',
          'kompetensiDasar',
          'kd',
        ]),
        'indicator': fallback(['indicator', 'indikator']),
        'learning_objective': fallback([
          'learning_objective',
          'tujuan_pembelajaran',
          'learning_objectives',
        ]),
        'main_material': fallback(['main_material']),
        'learning_method': fallback(['learning_method']),
        'media_tools': fallback(['media_tools']),
        'learning_source': fallback(['learning_source']),
        'learning_activities': fallback([
          'learning_activities',
          'kegiatan_inti',
          'core_activities',
        ]),
        'assessment': fallback(['assessment', 'penilaian']),
        'status': fallback(['status']),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('RPP berhasil disimpan')));
    } catch (e) {
      if (kDebugMode) print('Save RPP error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _exportToWord() async {
    try {
      // Tunggu sebentar untuk memastikan plugin siap
      await Future.delayed(Duration(milliseconds: 100));

      // Create a new PDF document
      final PdfDocument document = PdfDocument();

      // Add a page
      final PdfPage page = document.pages.add();

      // Create PDF graphics
      final PdfGraphics graphics = page.graphics;

      // Create PDF font
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );

      // Draw title
      graphics.drawString(
        'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Draw content
      final List<String> lines = _editedContent.split('\n');
      double yPosition = 40;

      for (String line in lines) {
        if (line.trim().isEmpty) {
          yPosition += 10;
          continue;
        }

        graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(50, yPosition, page.size.width - 100, 15),
        );
        yPosition += 18;

        // Check for page break
        if (yPosition > page.size.height - 50) {
          document.pages.add();
          yPosition = 40;
        }
      }

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory dengan error handling
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${widget.rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('RPP berhasil diexport ke PDF')));
      }
    } catch (e) {
      if (kDebugMode) print('Export PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToText() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${widget.rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_editedContent, flush: true);

      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RPP berhasil diexport ke file text')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Text export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isDownloading = false;

  String? get _filePath {
    final fp = widget.rppData['file_path'];
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }

  String _getFileExtension(String filePath) {
    final fileName = _getFileName(filePath);
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex).toLowerCase();
  }

  String _getFileName(String filePath) {
    return Uri.parse(filePath).pathSegments.last;
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String ext) {
    switch (ext) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadAndOpenFile() async {
    final filePath = _filePath;
    if (filePath == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final response = await http.get(Uri.parse(filePath));

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = _getFileName(filePath);
        final localFile = File('${directory.path}/$fileName');
        await localFile.writeAsBytes(response.bodyBytes, flush: true);

        await OpenFile.open(localFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File berhasil diunduh')),
          );
        }
      } else {
        throw Exception('Gagal mengunduh file (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) print('Download file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _updateContent(String newContent) {
    setState(() {
      _editedContent = newContent;
    });
  }

  Color get _primaryColor => ColorUtils.getRoleColor('guru');

  LinearGradient get _headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Gradient Header
          _buildHeader(),
          // Body
          Expanded(
            child: _isEditing ? _buildEditor() : _buildPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _headerGradient,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit RPP' : 'Detail RPP',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.rppData['judul']?.toString() ??
                          widget.rppData['title']?.toString() ??
                          'RPP',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action buttons
              ..._buildHeaderActions(),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    if (_isEditing) {
      return [
        _buildHeaderButton(
          icon: Icons.save_rounded,
          onTap: () {
            _toggleEdit();
            _saveRPP();
          },
        ),
        SizedBox(width: 8),
        _buildHeaderButton(
          icon: Icons.close_rounded,
          onTap: _toggleEdit,
        ),
      ];
    }

    return [
      if (widget.isNew)
        _buildHeaderButton(
          icon: _isSaving ? null : Icons.save_rounded,
          isLoading: _isSaving,
          onTap: _isSaving ? null : _saveRPP,
        ),
      if (!widget.isNew) ...[
        _buildHeaderButton(
          icon: Icons.edit_outlined,
          onTap: _toggleEdit,
        ),
        SizedBox(width: 8),
        if (_hasAiAdditionalData) ...[
          _buildHeaderButton(
            icon: Icons.smart_toy_rounded,
            onTap: _openAiRppScreen,
          ),
          SizedBox(width: 8),
        ],
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'text') _exportToText();
            if (value == 'pdf') _exportToWord();
            if (value == 'copy') _copyToClipboard();
          },
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Export ke PDF'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'text',
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Text('Export ke Text'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.content_copy, color: _primaryColor, size: 20),
                  SizedBox(width: 10),
                  Text('Copy ke Clipboard'),
                ],
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _buildHeaderButton({
    IconData? icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isLoading
            ? Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormatButton('B', Icons.format_bold, () {}),
                _buildFormatButton('I', Icons.format_italic, () {}),
                _buildFormatButton('U', Icons.format_underlined, () {}),
                _buildFormatButton('H1', Icons.title, () {}),
                _buildFormatButton('Table', Icons.table_chart, () {}),
                _buildFormatButton('List', Icons.list, () {}),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: TextEditingController(text: _editedContent),
                onChanged: _updateContent,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Ketik RPP disini...',
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Courier',
                  height: 1.5,
                  color: ColorUtils.slate800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20, color: ColorUtils.slate600),
      onPressed: onPressed,
      tooltip: text,
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // File attachment card
          if (_filePath != null) _buildFileCard(),
          // RPP content
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: _buildFormattedContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard() {
    final filePath = _filePath!;
    final ext = _getFileExtension(filePath);
    final fileName = _getFileName(filePath);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isDownloading ? null : _downloadAndOpenFile,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFileIconColor(ext).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getFileIconColor(ext).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    _getFileIcon(ext),
                    color: _getFileIconColor(ext),
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Lampiran RPP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _isDownloading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      )
                    : Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent() {
    final lines = _editedContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) {
          return SizedBox(height: 16);
        }

        if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
          return Column(
            children: [
              Text(
                line,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
            ],
          );
        }

        if (line.startsWith('=')) {
          return Container(
            height: 2,
            color: ColorUtils.slate200,
            margin: EdgeInsets.symmetric(vertical: 8),
          );
        }

        if (line.startsWith('|')) {
          return _buildTableRow(line);
        }

        if (line.startsWith('A.') ||
            line.startsWith('B.') ||
            line.startsWith('C.')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 8),
            ],
          );
        }

        if (line.contains('Media :') || line.contains('Alat/Bahan :')) {
          return Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          );
        }

        if (line.startsWith('•') ||
            line.startsWith('1.') ||
            line.startsWith('2.')) {
          return Padding(
            padding: EdgeInsets.only(left: 16, bottom: 4),
            child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
          );
        }

        if (line.contains('Mengetahui') ||
            line.contains('Kepala Sekolah') ||
            line.contains('Guru Mata Pelajaran')) {
          return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              line,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
        );
      }).toList(),
    );
  }

  Widget _buildTableRow(String line) {
    final cells = line
        .split('|')
        .where((cell) => cell.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Text(
                cell.trim(),
                style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _editedContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('RPP berhasil disalin ke clipboard')),
    );
  }
}
