import 'dart:convert';

import 'mensa.dart' show isoWeek;
import 'mensa_week.dart';

/// Skripte, mit denen die App auf der Seite des Caterers bestellt bzw.
/// abbestellt (MealOrderRunner, ui/mensa/meal_order.dart).
///
/// Ursache (Wunsch 27.10.26): Bestellen und Abbestellen sollen in der
/// eigenen Ansicht gehen. Die Caterer haben keine offene Schnittstelle;
/// die App drückt deshalb auf der echten Seite dieselben Knöpfe wie ein
/// Mensch – deren eigene Skripte erledigen den Rest. Danach liest die App
/// die Woche neu und meldet Erfolg nur, wenn die Seite ihn zeigt.
///
/// Rückgabe jedes Skripts: „ok“ (gedrückt), „missing“ (Element fehlt, z. B.
/// geänderter Aufbau) oder „blocked“ (Knopf gesperrt, Frist vorbei).
///
/// Sicherheit: Rückfragen der Seite (window.confirm) bestätigt das Skript,
/// weil der Mensch vorher in der App bestätigt hat (confirmMealChange);
/// Hinweisfenster (alert) werden still geschlossen. Beides gilt nur in der
/// unsichtbaren Ansicht dieses einen Vorgangs.
/// Geprüft am 27.10.26 in Chromium gegen nachgebaute Seiten beider Aufbauten
/// (Klick, Rückfrage, Speichern-Knopf, gesperrter Knopf, fehlendes Element).
String mealOrderJs(MealLayout kind, DateTime day, MealOption option) =>
    switch (kind) {
      MealLayout.dayList => _dayListJs(option.id ?? '', 'plus'),
      MealLayout.tabs => _tabsOrderJs(_date(day), option.id ?? '', _week(day)),
    };

String mealCancelJs(MealLayout kind, DateTime day, MealOption? ordered) =>
    switch (kind) {
      MealLayout.dayList => _dayListJs(ordered?.id ?? '', 'minus'),
      MealLayout.tabs => _tabsCancelJs(_date(day), _week(day)),
    };

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// „2026_44“ wie im Wochenwähler der Reiter-Seite.
String _week(DateTime d) {
  final w = isoWeek(d);
  return '${w.year}_${w.week}';
}

/// Vor jedem Klick (Prüfung 27.10.26):
/// - genau EINE Rückfrage (window.confirm) bestätigen, weitere ablehnen;
/// - schon offene Fenster markieren (mealModalJs wertet nur neue);
/// - laufende Anfragen zählen (XHR/fetch), damit „Ruhe“ erst gilt, wenn
///   die Seite fertig ist.
const _prepare = '''
  var used = false;
  window.confirm = function () { if (used) return false; used = true; return true; };
  window.alert = function () {};
  document.querySelectorAll('.modal, .bootbox').forEach(function (m) { m.setAttribute('data-fork-pre', '1'); });
  if (!window.__mealXhr) {
    window.__mealXhr = { n: 0 };
    var send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      var x = this; window.__mealXhr.n++;
      x.addEventListener('loadend', function () { window.__mealXhr.n--; });
      return send.apply(x, arguments);
    };
    if (window.fetch) {
      var f = window.fetch;
      window.fetch = function () {
        window.__mealXhr.n++;
        return f.apply(this, arguments).finally(function () { window.__mealXhr.n--; });
      };
    }
  }
  function esc(v) { return window.CSS && CSS.escape ? CSS.escape(v) : String(v).replace(/["\\\\]/g, ''); }
''';

/// Tagesliste: Knopf „+“ bzw. „−“ im Formular des Gerichts (Tagesliste
/// `#sv-mof-…`, sonst breite Tabelle `#mof-…`).
String _dayListJs(String id, String method) =>
    '''
(function (id, method) {
$_prepare
  var f = document.getElementById('sv-mof-' + id) || document.getElementById('mof-' + id);
  if (!f) return 'missing';
  var b = f.querySelector('button[data-method=' + method + ']');
  if (!b) return 'missing';
  if (b.classList.contains('disabled') || b.disabled) return 'blocked';
  b.click();
  return 'ok';
})(${jsonEncode(id)}, ${jsonEncode(method)})
''';

/// Reiter: Wochenwähler muss die Woche des Tages zeigen (sonst könnte
/// „Speichern“ in einer anderen Woche buchen); Menülinie anhaken, prüfen,
/// dass das versteckte Feld derselben Esser-Spalte (`data-block`) sie
/// trägt, dann „Menüauswahl speichern“.
String _tabsOrderJs(String day, String rel, String week) =>
    '''
(function (day, rel, week) {
$_prepare
  var sel = document.querySelector('#datenauswahl select[name=week]');
  if (sel && sel.value && sel.value !== week) return 'missing';
  var pane = document.querySelector('.tab-pane.day[name="' + esc(day) + '"]');
  if (!pane) return 'missing';
  var p = pane.querySelector('.panel.menue[rel="' + esc(rel) + '"]');
  if (!p) return 'missing';
  if (p.classList.contains('disabled')) return 'blocked';
  var block = p.getAttribute('data-block') || '0';
  var field = pane.querySelector('.hiddenmenuefield[data-block="' + esc(block) + '"]') ||
    pane.querySelector('.hiddenmenuefield');
  function chosen() { return field ? field.value === rel : p.classList.contains('active'); }
  if (!chosen()) {
    var cb = p.querySelector('input[type=checkbox]');
    (cb || p).click();
  }
  if (!chosen()) {
    var h = p.querySelector('.panel-heading');
    if (h) h.click();
  }
  if (!chosen()) return 'missing';
  var save = document.querySelector('button[name=submit_bestellung]');
  if (!save) return 'missing';
  setTimeout(function () { save.click(); }, 300);
  return 'ok';
})(${jsonEncode(day)}, ${jsonEncode(rel)}, ${jsonEncode(week)})
''';

/// Reiter: „Abbestellen“ der gewählten Linie; bleibt die Seite danach
/// stehen und ist die Wahl leer, zusätzlich „Menüauswahl speichern“.
String _tabsCancelJs(String day, String week) =>
    '''
(function (day, week) {
$_prepare
  var sel = document.querySelector('#datenauswahl select[name=week]');
  if (sel && sel.value && sel.value !== week) return 'missing';
  var pane = document.querySelector('.tab-pane.day[name="' + esc(day) + '"]');
  if (!pane) return 'missing';
  var p = pane.querySelector('.panel.menue.active');
  var field = null;
  if (p) {
    field = pane.querySelector('.hiddenmenuefield[data-block="' + esc(p.getAttribute('data-block') || '0') + '"]');
  } else {
    field = pane.querySelector('.hiddenmenuefield');
    if (field && field.value) p = pane.querySelector('.panel.menue[rel="' + esc(field.value) + '"]');
  }
  if (!p) return 'missing';
  if (p.classList.contains('disabled')) return 'blocked';
  var b = p.querySelector('button[onclick*="cancelOrder"]');
  if (b) b.click(); else { var cb = p.querySelector('input[type=checkbox]'); if (cb) cb.click(); else return 'missing'; }
  setTimeout(function () {
    if (field && field.value) return;
    var save = document.querySelector('button[name=submit_bestellung]');
    if (save) save.click();
  }, 600);
  return 'ok';
})(${jsonEncode(day)}, ${jsonEncode(week)})
''';

/// Zustand nach dem Klick: neues Fenster der Seite (Bootstrap/Bootbox) und
/// laufende Anfragen. Ein Fenster wird nur mit „Bestätigen/OK“ der Bootbox
/// geschlossen; hat es Eingabefelder oder keinen solchen Knopf, bleibt es
/// offen („open“) und die App meldet seinen Text. Ergebnis JSON
/// {"s":"none"|"clicked"|"open","t":"…","p":Anzahl laufender Anfragen}.
const mealModalJs = r'''
(function () {
  var p = window.__mealXhr ? window.__mealXhr.n : 0;
  var ms = document.querySelectorAll('.bootbox.in, .bootbox.show, .modal.in, .modal.show');
  var m = null;
  for (var i = 0; i < ms.length; i++) { if (!ms[i].getAttribute('data-fork-pre')) { m = ms[i]; break; } }
  if (!m) return JSON.stringify({ s: 'none', p: p });
  var body = m.querySelector('.modal-body, .bootbox-body') || m;
  var text = (body.innerText || body.textContent || '').trim().slice(0, 300);
  if (m.querySelector('input:not([type=hidden]), select, textarea')) {
    return JSON.stringify({ s: 'open', t: text, p: p });
  }
  var b = m.querySelector('[data-bb-handler=confirm]') || m.querySelector('[data-bb-handler=ok]');
  if (b && !m.getAttribute('data-fork-clicked')) {
    m.setAttribute('data-fork-clicked', '1');
    b.click();
    return JSON.stringify({ s: 'clicked', t: text, p: p });
  }
  return JSON.stringify({ s: 'open', t: text, p: p });
})()
''';

/// Marke vor dem Neuladen zur Prüfung: Eine Seite, die sie noch trägt, ist
/// nicht neu vom Server (Prüfung 27.10.26, Fehlerfolg durch alten DOM).
const mealStaleMarkJs = 'window.__mealStale = 1;';
const mealIsStaleJs = "window.__mealStale ? 'stale' : 'fresh'";
