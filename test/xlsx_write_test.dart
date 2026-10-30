import 'package:easy_lesson/xlsx.dart';
import 'package:easy_lesson/xlsx_write.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writeXlsx si rilegge con readXlsx (primo foglio)', () {
    final bytes = writeXlsx({
      '1A IT': [
        ['Ora', 'Orario', 'Lunedì'],
        ['1ª', '07:50-08:40', 'Matematica\nDocente 001 & Co <lab>'],
        ['2ª', '', ''],
      ],
      'Foglio: con / caratteri strani [x]': [
        ['a'],
      ],
    });
    final grid = readXlsx(bytes);
    expect(grid[0], ['Ora', 'Orario', 'Lunedì']);
    expect(grid[1][2], 'Matematica\nDocente 001 & Co <lab>');
    expect(grid[2], ['2ª']);
  });

  test('colName', () {
    expect(colName(0), 'A');
    expect(colName(25), 'Z');
    expect(colName(26), 'AA');
    expect(colName(701), 'ZZ');
    expect(colName(702), 'AAA');
  });
}
