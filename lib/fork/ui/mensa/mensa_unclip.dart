/// Skript für die eingebettete Bestellseite (MensaPage): hebt abgeschnittene
/// Texte auf, damit Gerichte vollständig zu lesen sind.
///
/// Ursache (Rückmeldung 26.10.26, Bildschirmfoto): Die Bestellseite eines
/// Caterers legt die Zeilen der Woche mit fester Höhe und
/// `overflow: hidden` an. In der App ist die Schrift größer als im
/// Entwurf der Seite (Android-WebView übernimmt die Systemschriftgröße), und
/// die zweite Zeile des Gerichts wurde mitten im Text abgeschnitten.
///
/// Vorgehen, ohne den Caterer zu kennen (sein Name steht bewusst nirgends
/// im Code, mensa.dart): Für jedes Element mit eigenem Text prüft das
/// Skript, ob der Text unten über einen abschneidenden Vorfahren (bis
/// sechs Ebenen, DEPTH) hinausragt; nur dann wird dieser Vorfahr auf
/// `height: auto; overflow: visible` gesetzt. Zeilenbegrenzung
/// (`-webkit-line-clamp`) am Text selbst wird aufgehoben.
///
/// Grenzen:
/// - Zugeklappte Bereiche (Höhe 0, z. B. Details hinter „⌄“) bleiben zu:
///   Elemente und Vorfahren ohne sichtbare Höhe werden übersprungen.
/// - Abgeschnittene Breite (eine Zeile mit „…“) bleibt, wenn die Seite den
///   Text bewusst einzeilig hält und kein Höhenproblem vorliegt.
/// - Läuft nach jedem Laden und bei Änderungen der Seite (MutationObserver,
///   gebündelt nach 150 ms), etwa beim Wochenwechsel.
/// Geprüft am 26.10.26 mit einer nachgebauten Wochenseite in Chromium
/// (Playwright): feste Zeilenhöhe, Zeilenbegrenzung, zugeklappte Details,
/// nachgeladene Woche.
const mensaUnclipJs = r'''
(function () {
  if (window.__forkUnclip) { window.__forkUnclip(); return; }
  var DEPTH = 6;
  function clips(cs) {
    return cs.overflow === 'hidden' || cs.overflowY === 'hidden' ||
      cs.overflow === 'clip' || cs.overflowY === 'clip';
  }
  function open(el) {
    el.style.setProperty('height', 'auto', 'important');
    el.style.setProperty('max-height', 'none', 'important');
    el.style.setProperty('overflow', 'visible', 'important');
  }
  function ownText(el) {
    for (var n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3 && n.nodeValue.trim().length > 2) return true;
    }
    return false;
  }
  function fix() {
    if (!document.body) return;
    var all = document.body.getElementsByTagName('*');
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (!ownText(el) || el.clientHeight === 0) continue;
      var cs = getComputedStyle(el);
      if (cs.webkitLineClamp && cs.webkitLineClamp !== 'none' &&
          el.scrollHeight > el.clientHeight + 1) {
        el.style.setProperty('-webkit-line-clamp', 'unset', 'important');
        el.style.setProperty('display', 'block', 'important');
        open(el);
      } else if (clips(cs) && el.scrollHeight > el.clientHeight + 1) {
        open(el);
      }
      var bottom = el.getBoundingClientRect().top + el.scrollHeight;
      var p = el.parentElement;
      for (var d = 0; p && p !== document.body && d < DEPTH; d++) {
        if (p.clientHeight > 0 && clips(getComputedStyle(p)) &&
            bottom > p.getBoundingClientRect().bottom + 1) {
          open(p);
        }
        p = p.parentElement;
      }
    }
  }
  window.__forkUnclip = fix;
  fix();
  var t;
  new MutationObserver(function () {
    clearTimeout(t);
    t = setTimeout(fix, 150);
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
''';
