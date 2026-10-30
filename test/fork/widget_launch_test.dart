import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/widget/widget_launch.dart';

/// Klick-Ziele des Widgets (Entwurf 10, 30.10.26) – Adresse aus Kotlin.
void main() {
  test('Adresse lesen: Kind und Ziel', () {
    expect(
      WidgetLaunch.parse(
        Uri.parse('schulportal-widget://open?account=12&target=exams'),
      ),
      const WidgetLaunch(account: 12, target: WidgetTarget.exams),
    );
    expect(
      WidgetLaunch.parse(Uri.parse('schulportal-widget://open?target=meal')),
      const WidgetLaunch(target: WidgetTarget.meal),
    );
  });

  test('Unbekanntes Ziel → Heute; fremde Adressen ignoriert', () {
    expect(
      WidgetLaunch.parse(
        Uri.parse('schulportal-widget://open?account=3&target=neu'),
      ),
      const WidgetLaunch(account: 3, target: WidgetTarget.today),
    );
    expect(WidgetLaunch.parse(Uri.parse('https://example.org/?x=1')), isNull);
    expect(WidgetLaunch.parse(null), isNull);
  });
}
