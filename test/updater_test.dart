import 'package:easy_lesson/updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioni stabili', () {
    expect(compareVersions('2.4.0', '2.3.0') > 0, true);
    expect(compareVersions('2.0.10', '2.0.9') > 0, true);
    expect(compareVersions('2.4.0', '2.4.0'), 0);
  });

  test('beta e stabili', () {
    expect(compareVersions('2.5.0-beta.1', '2.4.0') > 0, true); // la beta della 2.5 è più nuova della 2.4
    expect(compareVersions('2.5.0', '2.5.0-beta.3') > 0, true); // la stabile vince sulla sua beta
    expect(compareVersions('2.5.0-beta.2', '2.5.0-beta.1') > 0, true);
    expect(compareVersions('2.5.0-beta.10', '2.5.0-beta.9') > 0, true);
    expect(compareVersions('2.4.0-test', '2.4.0') < 0, true);
  });
}
