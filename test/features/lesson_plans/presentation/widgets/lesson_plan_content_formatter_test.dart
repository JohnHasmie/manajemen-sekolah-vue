// ignore_for_file: lines_longer_than_80_chars
// Unit tests for LessonPlanContentFormatter.
// All methods are static — no widget setup required, like testing a Laravel
// helper class purely via unit test assertions.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';

void main() {
  // ---------------------------------------------------------------------------
  // stripHtml
  // ---------------------------------------------------------------------------
  group('LessonPlanContentFormatter.stripHtml', () {
    test('returns empty string unchanged', () {
      expect(LessonPlanContentFormatter.stripHtml(''), '');
    });

    test('strips generic HTML tags leaving plain text', () {
      final result = LessonPlanContentFormatter.stripHtml('<b>Hello</b> world');
      expect(result, 'Hello world');
    });

    test('converts <br> and <br/> to newlines', () {
      final result = LessonPlanContentFormatter.stripHtml(
        'line1<br>line2<br/>line3',
      );
      expect(result, contains('line1'));
      expect(result, contains('line2'));
      expect(result, contains('line3'));
    });

    test('decodes common HTML entities', () {
      final result = LessonPlanContentFormatter.stripHtml(
        '&amp; &lt; &gt; &quot; &#39; &nbsp;',
      );
      expect(result, contains('&'));
      expect(result, contains('<'));
      expect(result, contains('>'));
      expect(result, contains('"'));
      expect(result, contains("'"));
    });

    test('converts <ul><li> to bullet points', () {
      const html = '<ul><li>Item A</li><li>Item B</li></ul>';
      final result = LessonPlanContentFormatter.stripHtml(html);
      expect(result, contains('• Item A'));
      expect(result, contains('• Item B'));
    });

    test('converts <ol><li> to numbered items', () {
      const html = '<ol><li>First</li><li>Second</li></ol>';
      final result = LessonPlanContentFormatter.stripHtml(html);
      expect(result, contains('1. First'));
      expect(result, contains('2. Second'));
    });

    test('collapses three or more consecutive blank lines to at most two', () {
      const html = 'A\n\n\n\nB';
      final result = LessonPlanContentFormatter.stripHtml(html);
      expect(result, isNot(contains('\n\n\n')));
    });

    test('trims leading and trailing whitespace', () {
      final result = LessonPlanContentFormatter.stripHtml('   <p>Hello</p>   ');
      expect(result.startsWith(' '), isFalse);
      expect(result.endsWith(' '), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // format
  // ---------------------------------------------------------------------------
  group('LessonPlanContentFormatter.format', () {
    test('always starts with the RPP header line', () {
      final result = LessonPlanContentFormatter.format({});
      expect(result, startsWith('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)'));
    });

    test('uses default title "RPP" when no title field is provided', () {
      final result = LessonPlanContentFormatter.format({});
      expect(result, contains('Judul\t\t\t: RPP'));
    });

    test('picks up "judul" as the title field', () {
      final result = LessonPlanContentFormatter.format({
        'judul': 'Fisika Dasar',
      });
      expect(result, contains('Fisika Dasar'));
    });

    test('falls back to "title" when "judul" is absent', () {
      final result = LessonPlanContentFormatter.format({
        'title': 'Basic Physics',
      });
      expect(result, contains('Basic Physics'));
    });

    test('includes Mata Pelajaran line when subject name is provided', () {
      final result = LessonPlanContentFormatter.format({
        'mata_pelajaran_nama': 'Matematika',
      });
      expect(result, contains('Mata Pelajaran'));
      expect(result, contains('Matematika'));
    });

    test('omits optional fields that are absent from the map', () {
      final result = LessonPlanContentFormatter.format({'judul': 'Test RPP'});
      // The header line "Mata Pelajaran\t: ..." must not appear;
      // note the signature block contains "Guru Mata Pelajaran" so we check
      // for the tab-formatted header specifically.
      expect(result, isNot(contains('Mata Pelajaran\t')));
      expect(result, isNot(contains('Kelas\t')));
    });

    test('includes AI footer when ai_generated is true', () {
      final result = LessonPlanContentFormatter.format({'ai_generated': true});
      expect(result, contains('digenerate secara otomatis menggunakan AI'));
    });

    test('does not include AI footer when ai_generated is false', () {
      final result = LessonPlanContentFormatter.format({'ai_generated': false});
      expect(result, isNot(contains('digenerate secara otomatis')));
    });

    test('numbers objectives sequentially for non-AI RPP', () {
      final result = LessonPlanContentFormatter.format({
        'tujuan_pembelajaran': 'Objective one\nObjective two',
        'ai_generated': false,
      });
      expect(result, contains('1. Objective one'));
      expect(result, contains('2. Objective two'));
    });

    test('always ends with the signature block lines', () {
      final result = LessonPlanContentFormatter.format({});
      expect(result, contains('Kepala Sekolah'));
      expect(result, contains('Guru Mata Pelajaran'));
    });

    test('section labels use alphabetic letters (A, B, C…)', () {
      final result = LessonPlanContentFormatter.format({
        'kompetensi_inti': 'KI content',
        'kompetensi_dasar': 'KD content',
      });
      expect(result, contains('A. KOMPETENSI INTI'));
      expect(result, contains('B. KOMPETENSI DASAR'));
    });

    test(
      'includes KEGIATAN PEMBELAJARAN section with sub-sections when all three activity fields are given',
      () {
        final result = LessonPlanContentFormatter.format({
          'kegiatan_pendahuluan': 'Opening',
          'learning_activities': 'Core activity',
          'kegiatan_penutup': 'Closing',
        });
        expect(result, contains('Kegiatan Pendahuluan'));
        expect(result, contains('Kegiatan Inti'));
        expect(result, contains('Kegiatan Penutup'));
      },
    );

    test('includes time in minutes when waktu_pendahuluan is provided', () {
      final result = LessonPlanContentFormatter.format({
        'kegiatan_pendahuluan': 'Opening',
        'waktu_pendahuluan': '15',
        'learning_activities': 'Core',
        'kegiatan_penutup': 'Close',
      });
      expect(result, contains('(15 menit)'));
    });
  });
}
