import 'package:easy_lesson/ui/code_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('link del codice: andata e ritorno, anche con simboli', () {
    const code = 'Ab3\$k-9€xQ#-zz/@7-a+b=c';
    expect(parseCodeText(accountLink(code)), ('login', code));
    expect(parseCodeText(recoveryLink(code)), ('recover', code));
    expect(parseCodeText('  $code '), ('raw', code));
    expect(parseCodeText('easylesson://import?d=xyz').$1, 'raw');
    expect(parseCodeText('easylesson://login?c=').$1, 'raw');
  });
}
