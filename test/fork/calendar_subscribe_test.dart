import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/calendar_subscribe.dart';

void main() {
  test('Google-Abo-Link: webcal als cid, Abfrage sauber kodiert', () {
    final u = googleCalendarSubscribeUrl(
      'https://start.example.de/kalender.php?a=ical&i=1234&t=abc',
    );
    expect(u.host, 'calendar.google.com');
    expect(u.path, '/calendar/render');
    expect(
      u.queryParameters['cid'],
      'webcal://start.example.de/kalender.php?a=ical&i=1234&t=abc',
    );
    expect(u.toString(), contains('cid=webcal%3A%2F%2F'));
    expect(
      googleCalendarSubscribeUrl('webcal://x.de/c.ics').queryParameters['cid'],
      'webcal://x.de/c.ics',
    );
    expect(
      googleCalendarSubscribeUrl('x.de/c.ics').queryParameters['cid'],
      'webcal://x.de/c.ics',
    );
  });
}
