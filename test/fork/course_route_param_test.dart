import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Eltern-Kurs-IDs lauten `<id>&p=<Kind>` (fork/lessons_parent.dart). Sie
/// stehen im Pfad von /parent/lessons/course/:courseId — dieser Test sichert,
/// dass go_router `&` und `=` im Pfadparameter unverändert durchreicht und die
/// Query (`title`) getrennt bleibt.
void main() {
  testWidgets('courseId mit &p= bleibt ganz', (tester) async {
    String? id;
    String? title;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/parent/lessons/course/:courseId',
          builder: (context, state) {
            id = state.pathParameters['courseId'];
            title = state.uri.queryParameters['title'];
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/parent/lessons/course/501&p=100?title=${Uri.encodeComponent('Mathe 6a')}');
    await tester.pumpAndSettle();
    expect(id, '501&p=100');
    expect(title, 'Mathe 6a');
    expect('meinunterricht.php?a=sus_view&id=$id', 'meinunterricht.php?a=sus_view&id=501&p=100');
  });
}
