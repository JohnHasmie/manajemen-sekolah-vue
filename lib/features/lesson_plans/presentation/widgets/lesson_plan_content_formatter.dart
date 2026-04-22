// Helper class for formatting RPP (lesson plan) plain-text content.
//
// Extracted from RPPDetailPageState to keep the screen file under 1,500 lines.
// All methods are static — no instances needed, like a Laravel helper/trait.

/// Formats a raw RPP data map into a human-readable plain-text string, and
/// strips HTML tags from AI-generated field content.
///
/// Used by [RPPDetailPageState] to build the editable preview content.
class LessonPlanContentFormatter {
  /// Converts an RPP data map into a formatted plain-text string.
  ///
  /// Accepts the same [lessonPlanData] map that the screen keeps in state.
  /// Equivalent to calling the old private `_formatLessonPlanContent()` method.
  static String format(Map<String, dynamic> lessonPlanData) {
    final buffer = StringBuffer();

    String getField(List<String> keys, {String defaultValue = ''}) {
      for (final key in keys) {
        final value = lessonPlanData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return defaultValue;
    }

    final title = getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = getField(['mata_pelajaran_nama', 'subject_name']);
    final className = getField(['kelas_nama', 'class_name']);
    final semester = getField(['semester']);
    final academicYear = getField(['tahun_ajaran', 'academic_year']);
    final teacherName = getField(['guru_nama', 'teacher_name']);
    final status = getField(['status']);

    // Header fields that may come from AI generation or manual input
    final unit = getField(['satuan_pendidikan', 'education_unit']);
    final theme = getField(['tema', 'theme']);
    final subTheme = getField(['sub_tema', 'sub_theme']);
    final sequence = getField(['pembelajaran_ke', 'learning_sequence']);
    final timeAllocation = getField(['alokasi_waktu', 'time_allocation']);

    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln();

    // Header information from database
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

    // Additional header (from AI generation or manual input)
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

    // Check if RPP is AI-generated (10-component API format)
    final bool isAi =
        lessonPlanData['ai_generated'] == true ||
        lessonPlanData['is_ai_generated'] == true;

    // Core Competencies & Basic Competencies (if available)
    final String coreCompetency = getField([
      'kompetensi_inti',
      'coreCompetency',
      'ki',
      'core_competence',
    ]);
    final String basicCompetency = getField([
      'kompetensi_dasar',
      'basicCompetency',
      'kd',
      'basic_competence',
    ]);
    final String indikator = getField(['indikator', 'indicator']);

    int sectionIndex = 1;
    if (coreCompetency.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI INTI (KI)',
      );
      buffer.writeln(stripHtml(coreCompetency));
      buffer.writeln();
      sectionIndex++;
    }

    if (basicCompetency.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KOMPETENSI DASAR (KD)',
      );
      buffer.writeln(stripHtml(basicCompetency));
      buffer.writeln();
      sectionIndex++;
    }

    if (indikator.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. INDIKATOR');
      buffer.writeln(stripHtml(indikator));
      buffer.writeln();
      sectionIndex++;
    }

    // TUJUAN PEMBELAJARAN
    final objectives = getField([
      'learning_objective',
      'tujuan_pembelajaran',
      'learning_objectives',
    ]);

    if (objectives.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. TUJUAN PEMBELAJARAN',
      );
      sectionIndex++;
      if (isAi) {
        buffer.writeln(stripHtml(objectives));
      } else {
        final objectiveLines = objectives.split('\n');
        for (int i = 0; i < objectiveLines.length; i++) {
          if (objectiveLines[i].trim().isNotEmpty) {
            buffer.writeln('${i + 1}. ${objectiveLines[i].trim()}');
          }
        }
      }
      buffer.writeln();
    }

    // KEGIATAN PEMBELAJARAN
    final preliminaryActivities = getField([
      'kegiatan_pendahuluan',
      'preliminary_activities',
    ]);
    final coreActivities = getField([
      'learning_activities',
      'kegiatan_inti',
      'core_activities',
    ]);
    final closingActivities = getField([
      'kegiatan_penutup',
      'closing_activities',
    ]);

    if (coreActivities.isNotEmpty ||
        preliminaryActivities.isNotEmpty ||
        closingActivities.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. KEGIATAN PEMBELAJARAN',
      );
      buffer.writeln();
      sectionIndex++;

      if (preliminaryActivities.isEmpty && closingActivities.isEmpty) {
        // Data from DB (learning_activities) or AI - single field only
        buffer.writeln(stripHtml(coreActivities));
      } else {
        // Separate data (introduction, main, closing)
        if (preliminaryActivities.isNotEmpty) {
          final preliminaryTime = getField(['waktu_pendahuluan']);
          buffer.writeln(
            'Kegiatan Pendahuluan${preliminaryTime.isNotEmpty ? ' ($preliminaryTime menit)' : ''}',
          );
          for (final line in preliminaryActivities.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln('• ${line.trim()}');
            }
          }
          buffer.writeln();
        }

        if (coreActivities.isNotEmpty) {
          final coreTime = getField(['waktu_inti']);
          buffer.writeln(
            'Kegiatan Inti${coreTime.isNotEmpty ? ' ($coreTime menit)' : ''}',
          );
          for (final line in coreActivities.split('\n')) {
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

        if (closingActivities.isNotEmpty) {
          final closingTime = getField(['waktu_penutup']);
          buffer.writeln(
            'Kegiatan Penutup${closingTime.isNotEmpty ? ' ($closingTime menit)' : ''}',
          );
          for (final line in closingActivities.split('\n')) {
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
        buffer.writeln(stripHtml(assessment));
      } else {
        buffer.writeln(assessment);
      }
      buffer.writeln();
    }

    // Materials and Learning Resources (if available)
    final String mainMaterial = getField(['main_material']);
    final String learningMethod = getField(['learning_method']);
    final String mediaTools = getField(['media_tools']);
    final String learningSource = getField(['learning_source']);

    if (mainMaterial.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. MATERI POKOK');
      sectionIndex++;
      buffer.writeln(stripHtml(mainMaterial));
      buffer.writeln();
    }

    if (learningMethod.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. METODE PEMBELAJARAN',
      );
      sectionIndex++;
      buffer.writeln(stripHtml(learningMethod));
      buffer.writeln();
    }

    if (mediaTools.isNotEmpty) {
      buffer.writeln('${String.fromCharCode(64 + sectionIndex)}. MEDIA / ALAT');
      sectionIndex++;
      buffer.writeln(stripHtml(mediaTools));
      buffer.writeln();
    }

    if (learningSource.isNotEmpty) {
      buffer.writeln(
        '${String.fromCharCode(64 + sectionIndex)}. SUMBER BELAJAR',
      );
      sectionIndex++;
      buffer.writeln(stripHtml(learningSource));
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

    if (lessonPlanData['ai_generated'] == true ||
        lessonPlanData['is_ai_generated'] == true) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*RPP ini digenerate secara otomatis menggunakan AI*');
    }

    return buffer.toString();
  }

  /// Simple HTML stripper helper.
  ///
  /// Replaces list tags with newlines/bullets, removes remaining HTML tags,
  /// and decodes common HTML entities.
  static String stripHtml(String html) {
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
}
