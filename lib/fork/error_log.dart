import 'dart:convert';
import 'dart:io';

/// Fehlerprotokoll ohne Inhalte – nur auf dem Gerät, gesendet wird nur, was
/// der Nutzer selbst teilt (Einstellungen → Fehlersuche).
///
/// Ursache (Entscheidung 17.10.26): Automatisches Senden hieße Daten von
/// Kindern ohne Zutun an einen Server – der Fork hat bewusst keinen (Sentry
/// ausgebaut, glitchtip.dart). Ohne jede Erfassung fiele ein Lesefehler aber
/// nur auf, wenn jemand ihn bemerkt und beschreibt.
///
/// Was gespeichert wird: App-Version, Bereich (z. B. „vertretungsplan.php“),
/// Fehlertyp, Stapelzeilen (Code-Dateien bzw. Adressen) und Anzahl.
/// Bewusst NICHT: die Fehlermeldung – sie enthält oft Teile der Portalseite
/// (FormatException zeigt den gelesenen Text, also Namen und Noten). Grenze:
/// Der Fehlertyp allein ist manchmal unscharf; dann hilft der versteckte
/// Debug-Export (Version 7× antippen).
///
/// Stapel im Release sind wegen --split-debug-info nur Adressen; mit den
/// Symbolen des Release-Workflows (Artefakt „symbols“) übersetzt
/// `flutter symbolize` sie zurück in Dateien und Zeilen. Dafür bleiben die
/// Kopfzeilen (build_id, isolate_dso_base …) erhalten.
class ErrorRecord {
  const ErrorRecord({
    required this.first,
    required this.last,
    required this.version,
    required this.area,
    required this.type,
    required this.stack,
    this.count = 1,
  });

  factory ErrorRecord.fromJson(Map<String, dynamic> j) => ErrorRecord(
    first: DateTime.tryParse('${j['first']}') ?? DateTime(2000),
    last: DateTime.tryParse('${j['last']}') ?? DateTime(2000),
    version: '${j['version'] ?? ''}',
    area: '${j['area'] ?? ''}',
    type: '${j['type'] ?? ''}',
    stack: [for (final s in (j['stack'] as List? ?? const [])) '$s'],
    count: j['count'] is int ? j['count'] as int : 1,
  );

  final DateTime first;
  final DateTime last;
  final String version;
  final String area;
  final String type;
  final List<String> stack;
  final int count;

  /// Gleicher Fehler = gleiche Version, Bereich, Typ und Stapel.
  String get key => '$version|$area|$type|${stack.join('|')}';

  Map<String, dynamic> toJson() => {
    'first': first.toIso8601String(),
    'last': last.toIso8601String(),
    'version': version,
    'area': area,
    'type': type,
    'stack': stack,
    'count': count,
  };
}

/// Stapelzeilen ohne Inhalte: Kopfzeilen der Release-Stapel und die ersten
/// [maxFrames] Rahmen.
///
/// Ursache: Rahmen nennen Funktion und Datei, nie Daten; Zeilen anderer Art
/// (z. B. `<asynchronous suspension>`) bringen nichts. Grenze: Ein Rahmen
/// mit einer Closure im Namen bleibt – auch der trägt keine Daten.
List<String> safeStack(StackTrace? st, {int maxFrames = 12}) {
  if (st == null) return const [];
  const header = [
    'os:',
    'build_id:',
    'isolate_dso_base:',
    'isolate_instructions:',
    'vm_instructions:',
  ];
  final out = <String>[];
  var frames = 0;
  for (final raw in st.toString().split('\n')) {
    final line = raw.trim();
    if (header.any(line.startsWith)) {
      out.add(line);
    } else if (RegExp(r'^#\d+\s').hasMatch(line) && frames < maxFrames) {
      out.add(line);
      frames++;
    }
  }
  return out;
}

/// Ablage der Fehler; höchstens [maxRecords], neueste zuerst.
class ErrorLog {
  ErrorLog._();

  static final instance = ErrorLog._();

  static const maxRecords = 20;

  File? _file;
  String version = '';
  final List<ErrorRecord> _records = [];

  List<ErrorRecord> get records => List.unmodifiable(_records);

  /// Datei festlegen und Gespeichertes laden; vorher Erfasstes bleibt.
  void attach(File file) {
    _file = file;
    try {
      if (file.existsSync()) {
        final v = jsonDecode(file.readAsStringSync());
        if (v is List) {
          for (final j in v.whereType<Map<String, dynamic>>()) {
            _merge(ErrorRecord.fromJson(j));
          }
        }
      }
    } catch (_) {
      // Unlesbar – neu beginnen.
    }
    _save();
  }

  /// Fehler erfassen. [area] ist ein fester Name aus dem Code, nie Text aus
  /// dem Portal.
  void record(String area, Object error, StackTrace? st, {DateTime? now}) {
    final t = now ?? DateTime.now();
    _merge(
      ErrorRecord(
        first: t,
        last: t,
        version: version,
        area: area,
        type: error.runtimeType.toString(),
        stack: safeStack(st),
      ),
    );
    _save();
  }

  void clear() {
    _records.clear();
    _save();
  }

  void _merge(ErrorRecord r) {
    final i = _records.indexWhere((x) => x.key == r.key);
    if (i >= 0) {
      final old = _records.removeAt(i);
      r = ErrorRecord(
        first: old.first.isBefore(r.first) ? old.first : r.first,
        last: old.last.isAfter(r.last) ? old.last : r.last,
        version: r.version,
        area: r.area,
        type: r.type,
        stack: r.stack,
        count: old.count + r.count,
      );
    }
    _records.insert(0, r);
    _records.sort((a, b) => b.last.compareTo(a.last));
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
  }

  void _save() {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode([for (final r in _records) r.toJson()]));
    } catch (_) {
      // Kein Platz o. ä. – das Protokoll ist Hilfe, kein Muss.
    }
  }

  /// Text zum Teilen; genau das sieht der Nutzer vor dem Senden.
  String report({required String os}) {
    final b = StringBuffer()
      ..writeln('Schulportal-App – Fehlerbericht (ohne Inhalte)')
      ..writeln('System: $os');
    for (final r in _records) {
      b
        ..writeln()
        ..writeln('${r.version} · ${r.area} · ${r.type} · ${r.count}×')
        ..writeln(
          '${r.first.toIso8601String().substring(0, 16)} – '
          '${r.last.toIso8601String().substring(0, 16)}',
        );
      for (final s in r.stack) {
        b.writeln(s);
      }
    }
    return b.toString();
  }
}

/// Löscht im Zwischenspeicher Dateien, die länger als [maxAge] nicht
/// geändert wurden, und danach leere Ordner. Gibt die Zahl gelöschter
/// Dateien zurück.
///
/// Ursache (Entscheidung 17.10.26): Der Knopf „Zwischenspeicher leeren“ fiel
/// weg – im Speicher liegen nur geöffnete Kursdateien und Anhänge, und
/// Android räumt den temporären Ordner bei Platzmangel ohnehin selbst. Ohne
/// eigene Grenze wüchse er bei viel genutzten Kursen aber über Monate. Grenze:
/// Eine Datei, die man nach 30 Tagen wieder öffnet, wird neu geladen.
int pruneOldFiles(
  Directory dir, {
  Duration maxAge = const Duration(days: 30),
  DateTime? now,
}) {
  if (!dir.existsSync()) return 0;
  final limit = (now ?? DateTime.now()).subtract(maxAge);
  var n = 0;
  final dirs = <Directory>[];
  for (final e in dir.listSync(recursive: true, followLinks: false)) {
    if (e is File) {
      try {
        if (e.lastModifiedSync().isBefore(limit)) {
          e.deleteSync();
          n++;
        }
      } catch (_) {}
    } else if (e is Directory) {
      dirs.add(e);
    }
  }
  // Tiefste Ordner zuerst, damit auch verschachtelte leere verschwinden.
  dirs.sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final d in dirs) {
    try {
      if (d.listSync().isEmpty) d.deleteSync();
    } catch (_) {}
  }
  return n;
}
