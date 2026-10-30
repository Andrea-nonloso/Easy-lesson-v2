import 'package:easy_lesson/ui/theme.dart';
import 'package:easy_lesson/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tema e componenti base si disegnano', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: EmptyState(icon: Icons.school_outlined, title: 'Ciao!', message: 'Prova'),
      ),
    ));
    expect(find.text('Ciao!'), findsOneWidget);
    expect(find.text('Prova'), findsOneWidget);
  });
}
