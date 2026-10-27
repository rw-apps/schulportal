import 'dart:convert';

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
      MealLayout.tabs => _tabsOrderJs(_date(day), option.id ?? ''),
    };

String mealCancelJs(MealLayout kind, DateTime day, MealOption? ordered) =>
    switch (kind) {
      MealLayout.dayList => _dayListJs(ordered?.id ?? '', 'minus'),
      MealLayout.tabs => _tabsCancelJs(_date(day)),
    };

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _quiet = '''
  window.confirm = function () { return true; };
  window.alert = function () {};
''';

/// Tagesliste: Knopf „+“ bzw. „−“ im Formular des Gerichts (Tagesliste
/// `#sv-mof-…`, sonst breite Tabelle `#mof-…`).
String _dayListJs(String id, String method) =>
    '''
(function (id, method) {
$_quiet
  var f = document.getElementById('sv-mof-' + id) || document.getElementById('mof-' + id);
  if (!f) return 'missing';
  var b = f.querySelector('button[data-method=' + method + ']');
  if (!b) return 'missing';
  if (b.classList.contains('disabled') || b.disabled) return 'blocked';
  b.click();
  return 'ok';
})(${jsonEncode(id)}, ${jsonEncode(method)})
''';

/// Reiter: Menülinie im Tag anhaken (Haken, sonst Kopf der Linie), prüfen,
/// dass das versteckte Feld sie trägt, dann „Menüauswahl speichern“.
String _tabsOrderJs(String day, String rel) =>
    '''
(function (day, rel) {
$_quiet
  var pane = document.querySelector('.tab-pane.day[name="' + day + '"]');
  if (!pane) return 'missing';
  var p = pane.querySelector('.panel.menue[rel="' + rel + '"]');
  if (!p) return 'missing';
  if (p.classList.contains('disabled')) return 'blocked';
  var field = pane.querySelector('.hiddenmenuefield');
  function chosen() { return p.classList.contains('active') || (field && field.value === rel); }
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
})(${jsonEncode(day)}, ${jsonEncode(rel)})
''';

/// Reiter: „Abbestellen“ der gewählten Linie; bleibt die Seite danach
/// stehen und ist die Wahl leer, zusätzlich „Menüauswahl speichern“.
String _tabsCancelJs(String day) =>
    '''
(function (day) {
$_quiet
  var pane = document.querySelector('.tab-pane.day[name="' + day + '"]');
  if (!pane) return 'missing';
  var field = pane.querySelector('.hiddenmenuefield');
  var p = pane.querySelector('.panel.menue.active') ||
    (field && field.value ? pane.querySelector('.panel.menue[rel="' + field.value + '"]') : null);
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
})(${jsonEncode(day)})
''';

/// Offenes Fenster der Seite (Bootstrap/Bootbox) nach dem Klick: Text
/// merken und mit dem Hauptknopf schließen bzw. bestätigen. Ergebnis JSON
/// {"s":"none"|"clicked"|"open","t":"…"}.
const mealModalJs = r'''
(function () {
  var m = document.querySelector('.bootbox.in, .bootbox.show, .modal.in, .modal.show');
  if (!m) return JSON.stringify({ s: 'none' });
  var body = m.querySelector('.modal-body, .bootbox-body') || m;
  var text = (body.innerText || body.textContent || '').trim().slice(0, 300);
  // Reihenfolge zählt: erst Bestätigen/OK, nie zuerst „Abbrechen“.
  var sel = ['[data-bb-handler=confirm]', '[data-bb-handler=ok]', '.btn-primary', '.btn-success'];
  var b = null;
  for (var i = 0; i < sel.length && !b; i++) b = m.querySelector(sel[i]);
  if (!b) {
    var all = m.querySelectorAll('button');
    if (all.length === 1) b = all[0];
  }
  if (b) { b.click(); return JSON.stringify({ s: 'clicked', t: text }); }
  return JSON.stringify({ s: 'open', t: text });
})()
''';
