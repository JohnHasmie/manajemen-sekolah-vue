import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  test('insert empty text', () {
    String text = "";
    final doc = Document()..insert(0, text);
    print('Success: ${doc.toPlainText()}');
  });
}
