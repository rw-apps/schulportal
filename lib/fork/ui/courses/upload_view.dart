import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lanis/applets/lessons/student/upload_dates.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart' show OwnFile, PublicFile;

/// Angaben einer Abgabe aus „Mein Unterricht“, getrennt vom Parser.
///
/// Ursache (Abnahme 27.10.26, Entwurf 3 der Abgabeseite): Die Seite
/// (upload_page.dart) las jedes Feld als `snapshot.data["…"]` direkt im
/// Aufbau – ohne Portal war sie weder prüf- noch im Bild abnehmbar. Jetzt
/// baut [UploadInfo.fromPortal] einmal die Angaben, [UploadView] zeigt nur
/// noch. Grenze: Die Felder sind die von liblanis getUploadInfo (0.1.4);
/// fehlt eines, gilt der unten genannte Ersatzwert.
class UploadInfo {
  const UploadInfo({
    this.dates = const UploadDates(),
    this.deletionText,
    this.multipleFiles = false,
    this.anyNumberOfTimes = false,
    this.visibility,
    this.allowedTypes = const [],
    this.maxFileSize,
    this.open = false,
    this.additionalText,
    this.ownFiles = const [],
    this.publicFiles = const [],
  });

  /// Aus der Map von liblanis getUploadInfo. Unbekannte Wahrheitswerte
  /// gelten als „nicht erlaubt“ (die strengere Regel; der Server entscheidet
  /// ohnehin).
  factory UploadInfo.fromPortal(Map<dynamic, dynamic> data) => UploadInfo(
    dates: UploadDates.tryParse(
      startRaw: data["start"] as String?,
      deadlineRaw: data["deadline"] as String?,
      deletionRaw: data["automatic_deletion"] as String?,
    ),
    deletionText: data["automatic_deletion"] as String?,
    multipleFiles: data["upload_multiple_files"] == true,
    anyNumberOfTimes: data["upload_any_number_of_times"] == true,
    visibility: data["visibility"] as String?,
    allowedTypes: [
      for (final t in (data["allowed_file_types"] as List?) ?? const [])
        if (t.toString().trim().isNotEmpty) t.toString().trim(),
    ],
    maxFileSize: data["max_file_size"] as String?,
    // Das Formular (b/e/id) fehlt im Portal, solange keine Abgabe möglich
    // ist: vor dem Start, nach der Frist, nach der einzigen Abgabe.
    open: data["course_id"] != null,
    additionalText: (data["additional_text"] as String?)?.trim().isEmpty ?? true
        ? null
        : (data["additional_text"] as String).trim(),
    ownFiles: [...((data["own_files"] as List?) ?? const []).cast<OwnFile>()],
    publicFiles: [
      ...((data["public_files"] as List?) ?? const []).cast<PublicFile>(),
    ],
  );

  final UploadDates dates;
  final String? deletionText;
  final bool multipleFiles;
  final bool anyNumberOfTimes;
  final String? visibility;
  final List<String> allowedTypes;
  final String? maxFileSize;
  final bool open;
  final String? additionalText;
  final List<OwnFile> ownFiles;
  final List<PublicFile> publicFiles;

  /// Höchstzahl je Abgabe. Ursache (Abnahme 27.10.26, Ein-Datei-Regel):
  /// Bei „Hochladen mehrerer Dateien: nicht erlaubt“ zeigte die alte Seite
  /// „0 / 5“ und lehnte dann JEDE Abgabe mit einem Hinweisfenster ab
  /// (multipleOrUnlimitedSubmissionNotSupportedMsg). Jetzt geht genau eine
  /// Datei. Grenze: 5 ist die Zahl der Felder des Portals (file1…file5).
  int get maxFiles => multipleFiles ? 5 : 1;

  /// Abgegeben und keine weitere Abgabe erlaubt (Abnahme 27.10.26). Bei
  /// „beliebig oft“ bleibt die Seite offen, die eigenen Dateien stehen dann
  /// über „Weitere Datei hinzufügen“.
  bool get done => ownFiles.isNotEmpty && !anyNumberOfTimes;

  bool isBeforeStart(DateTime now) =>
      dates.start != null && now.isBefore(dates.start!);

  bool isPastDeadline(DateTime now) =>
      dates.deadline != null && !now.isBefore(dates.deadline!);

  /// Löschdatum erreicht: Dateien sind nicht mehr abrufbar.
  bool filesDeleted(DateTime now) =>
      dates.automaticDeletion != null &&
      !now.isBefore(dates.automaticDeletion!);

  /// Hinzufügen und Abgeben möglich (Fuß mit „Abgeben“ sichtbar).
  ///
  /// Nur das Formular des Portals ([open]) und die Einmal-Regel ([done])
  /// entscheiden, nicht die Uhr des Geräts. Ursache (Prüfung 28.10.26):
  /// Start und Frist werden als Ortszeit des Geräts gelesen; geht die Uhr
  /// vor oder steht das Gerät in einer anderen Zeitzone, sperrte die App,
  /// obwohl das Portal noch annahm – und eine während des Öffnens
  /// abgelaufene Frist ließ den Knopf stehen, „Abgeben“ tat dann still
  /// nichts. Grenze: [now] dient nur der Anzeige (Kopfkarte, Hinweis);
  /// eine zu späte Abgabe lehnt der Server ab, die Meldung kommt von dort.
  bool canSubmit(DateTime now) => open && !done;
}

/// Eine gewählte, noch nicht abgegebene Datei.
class UploadPick {
  const UploadPick({required this.name, this.size});
  final String name;

  /// Bytes; null/0 = unbekannt (file_picker.dart, PickedFile.size).
  final num? size;
}

/// Kopfzeile der Abgabeseite: Aufgabe und darunter Fach bzw. „Abgabe“.
///
/// Auch für Laden und Fehler (upload_page.dart), damit der Kopf beim
/// Wechsel nicht springt. Grenze: Höhe wächst mit der Schriftstufe
/// (KitFontStep × Systemschrift), sonst lief die zweite Zeile bei „Groß“
/// über die feste Leistenhöhe 56.
PreferredSizeWidget uploadAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  final k = Kit.of(context);
  final ts = MediaQuery.textScalerOf(context);
  double line(TextStyle s) => ts.scale(s.fontSize!) * s.height!;
  final height = math.max(
    kToolbarHeight,
    line(k.section) + line(k.cardMeta) + Sp.s,
  );
  return AppBar(
    backgroundColor: k.p.bg,
    surfaceTintColor: k.p.bg,
    foregroundColor: k.p.ink,
    toolbarHeight: height,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: k.section,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle ?? context.t.uploadKind,
          style: k.cardMeta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

/// Abgabeseite nach Entwurf 3 (Abnahme 27.10.26): Kopfkarte mit Frist,
/// Regel-Marken, „Deine Abgabe“, Hinweis der Lehrkraft, Dateien der
/// Lerngruppe; „Abgeben“ fest unten über der Systemleiste (wie
/// meal_week_page.dart).
///
/// Reine Anzeige: Daten in [info]/[picked], Handlungen als Rückrufe
/// (upload_page.dart, _UploadScreenState). null-Rückruf = Handlung fehlt.
class UploadView extends StatelessWidget {
  const UploadView({
    super.key,
    required this.title,
    this.subtitle,
    required this.info,
    required this.now,
    this.picked = const [],
    this.colorIndex = 0,
    this.uploading = false,
    this.onAdd,
    this.onRemovePicked,
    this.onSubmit,
    this.onOpenOwn,
    this.onLongPressOwn,
    this.onDeleteOwn,
    this.onOpenPublic,
  });

  final String title;
  final String? subtitle;
  final UploadInfo info;
  final DateTime now;
  final List<UploadPick> picked;
  final int colorIndex;
  final bool uploading;
  final VoidCallback? onAdd;
  final void Function(int index)? onRemovePicked;
  final VoidCallback? onSubmit;
  final void Function(OwnFile file)? onOpenOwn;
  final void Function(OwnFile file)? onLongPressOwn;
  final void Function(OwnFile file)? onDeleteOwn;
  final void Function(PublicFile file)? onOpenPublic;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final l = AppLocalizations.of(context);
    final deleted = info.filesDeleted(now);
    final canSubmit = info.canSubmit(now);
    final canAdd = canSubmit && !uploading && picked.length < info.maxFiles;

    final types = [
      if (info.allowedTypes.isNotEmpty) info.allowedTypes.join(', '),
      if (info.maxFileSize != null) t.uploadMaxSize(info.maxFileSize!),
    ].join(' · ');

    final deletion = info.dates.automaticDeletion != null
        ? formatDate(t, t.dateFull, info.dates.automaticDeletion!)
        : info.deletionText;
    final foot = [
      if (info.open && !info.done && !info.anyNumberOfTimes) t.uploadOnceNote,
      if (deleted)
        l.filesWereDeleted
      else if (deletion != null)
        t.uploadDeletesOn(deletion),
    ].join(' ');

    // Hinweis statt Hinzufügen, wenn nichts mehr geht und nichts da ist.
    String? closedNote;
    if (!canSubmit && info.ownFiles.isEmpty && picked.isEmpty) {
      if (info.isBeforeStart(now)) {
        final (amount, unit) = uploadWaitingTime(info.dates.start!, now);
        closedNote = l.submissionPossibleInX(switch (unit) {
          UploadWaitUnit.day => '$amount ${amount == 1 ? l.day : l.days}',
          UploadWaitUnit.hour => '$amount ${amount == 1 ? l.hour : l.hours}',
          UploadWaitUnit.minute =>
            '$amount ${amount == 1 ? l.minute : l.minutes}',
        });
      } else {
        closedNote = t.uploadNoSubmission;
      }
    }

    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: uploadAppBar(context, title: title, subtitle: subtitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.xl),
              children: [
                _Hero(info: info, now: now, colorIndex: colorIndex),
                const SizedBox(height: Sp.l),
                Wrap(
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    _RuleChip(
                      icon: Icons.insert_drive_file_outlined,
                      label: info.multipleFiles
                          ? t.uploadUpToFiles(info.maxFiles)
                          : t.uploadOneFile,
                    ),
                    _RuleChip(
                      icon: info.anyNumberOfTimes
                          ? Icons.repeat
                          : Icons.lock_outline,
                      label: info.anyNumberOfTimes
                          ? t.uploadRepeat
                          : t.uploadOnce,
                    ),
                    if (info.visibility != null &&
                        info.visibility!.trim().isNotEmpty)
                      _RuleChip(
                        icon: Icons.visibility_outlined,
                        label: uploadVisibilityLabel(t, info.visibility!),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.xl),
                _SectionTitle(t.uploadYours),
                for (final f in info.ownFiles) ...[
                  _FileTile(
                    name: f.name,
                    meta: [
                      t.uploadUploadedAt(_ownTime(t, f.time)),
                      if (f.comment != null && f.comment!.trim().isNotEmpty)
                        f.comment!.trim(),
                    ].join(' · '),
                    muted: deleted,
                    onTap: deleted || onOpenOwn == null
                        ? null
                        : () => onOpenOwn!(f),
                    onLongPress: deleted || onLongPressOwn == null
                        ? null
                        : () => onLongPressOwn!(f),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: k.kid(colorIndex).accent,
                          size: Sz.navIcon,
                        ),
                        if (!deleted && onDeleteOwn != null)
                          IconButton(
                            tooltip: l.deletePermanently,
                            onPressed: uploading ? null : () => onDeleteOwn!(f),
                            icon: Icon(Icons.delete_outline, color: k.p.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.s),
                ],
                for (final (i, p) in picked.indexed) ...[
                  _FileTile(
                    name: p.name,
                    meta: [
                      if ((p.size ?? 0) > 0)
                        formatUploadSize(p.size!, t.localeName),
                      t.uploadReady,
                    ].join(' · '),
                    trailing: IconButton(
                      tooltip: l.cancel,
                      onPressed: uploading || onRemovePicked == null
                          ? null
                          : () => onRemovePicked!(i),
                      icon: Icon(Icons.close, color: k.p.muted),
                    ),
                  ),
                  const SizedBox(height: Sp.s),
                ],
                if (canSubmit && picked.length < info.maxFiles)
                  _AddRow(
                    title: picked.isEmpty && info.ownFiles.isEmpty
                        ? t.uploadAdd
                        : t.uploadAddMore,
                    meta: types,
                    onTap: canAdd ? onAdd : null,
                  )
                else if (closedNote != null)
                  _NoteCard(closedNote),
                if (foot.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.s, Sp.xs, 0),
                    child: Text(foot, style: k.cardMeta),
                  ),
                if (info.additionalText != null) ...[
                  const SizedBox(height: Sp.xl),
                  _SectionTitle(t.uploadTeacherNote),
                  _NoteCard(info.additionalText!, strong: true),
                ],
                if (info.publicFiles.isNotEmpty) ...[
                  const SizedBox(height: Sp.xl),
                  _SectionTitle(t.uploadPublicFiles),
                  for (final f in info.publicFiles) ...[
                    _FileTile(
                      name: f.name,
                      meta: f.person,
                      muted: deleted,
                      onTap: deleted || onOpenPublic == null
                          ? null
                          : () => onOpenPublic!(f),
                    ),
                    const SizedBox(height: Sp.s),
                  ],
                ],
              ],
            ),
          ),
          // Fuß: fest, über der Gesten- bzw. Navigationsleiste. Entfällt,
          // wenn nichts mehr abzugeben ist; der Grund steht dann in der
          // Marke der Kopfkarte (_Hero).
          if (canSubmit)
            Container(
              decoration: BoxDecoration(
                color: k.p.bg,
                border: Border(
                  top: BorderSide(color: k.p.line, width: Sz.frame),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.page,
                    Sp.m,
                    Sp.page,
                    Sp.m,
                  ),
                  // Größer als der Standardknopf (Rückmeldung 27.10.26):
                  // volle Höhe Sz.button, Schrift tileTitle, Symbol navIcon.
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: k.p.strong,
                      foregroundColor: k.p.onStrong,
                      disabledBackgroundColor: k.p.line,
                      disabledForegroundColor: k.p.faint,
                      minimumSize: const Size.fromHeight(Sz.button),
                      textStyle: k.tileTitle,
                      iconSize: Sz.navIcon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Rad.button),
                      ),
                    ),
                    onPressed: picked.isEmpty || uploading ? null : onSubmit,
                    icon: uploading
                        ? SizedBox.square(
                            dimension: Sz.navIcon,
                            child: CircularProgressIndicator(
                              strokeWidth: Sz.cellBorder,
                              color: k.p.faint,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(
                      uploading ? t.uploadSubmitting : t.uploadSubmit,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zeit einer eigenen Abgabe: „Mo 26.10. · 19:42“, sonst der Text des
/// Portals (upload_dates.dart, parseOwnFileTime).
String _ownTime(ForkL10n t, String raw) {
  final d = parseOwnFileTime(raw);
  if (d == null) return cleanOwnFileTime(raw);
  return _shortWithTime(t, d);
}

String _shortWithTime(ForkL10n t, DateTime d) =>
    '${formatDate(t, t.dateShort, d)} · ${formatDate(t, 'HH:mm', d)}';

/// Sichtbarkeit des Portals als kurze Marke. Ursache (Abnahme 27.10.26):
/// „Dateien sichtbar für Lehrkraft“ passte nicht in eine Marke. Nur der
/// eindeutige Fall „nur die Lehrkraft“ wird übersetzt; alles andere steht
/// wie im Portal (Marke kürzt mit „…“).
String uploadVisibilityLabel(ForkL10n t, String raw) {
  final v = raw.trim().toLowerCase();
  final teacher = v.contains('lehrkr') || v.contains('lehrer');
  final others = RegExp(r'kurs|teilnehm|alle|gruppe|schüler|und|&').hasMatch(v);
  return teacher && !others ? t.uploadTeacherOnly : raw.trim();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
    child: Text(text, style: Kit.of(context).cardSection),
  );
}

BoxDecoration _card(Kit k) => BoxDecoration(
  color: k.p.card,
  borderRadius: BorderRadius.circular(Rad.card),
  boxShadow: k.cardShadow,
);

/// Kopfkarte: „ABGABE BIS“ / „ABGEGEBEN“, Datum, Marke mit Restzeit bzw.
/// Grund, Strich Start → Frist, Zeile „Seit …“ / „Beginnt …“ / „Frist bis …“.
/// Fehlende Daten lassen nur ihren Teil weg (upload_dates.dart).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.info,
    required this.now,
    required this.colorIndex,
  });

  final UploadInfo info;
  final DateTime now;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final kid = k.kid(colorIndex);
    final start = info.dates.start;
    final deadline = info.dates.deadline;
    final done = info.done;

    // Zeitpunkt der letzten eigenen Abgabe (nur bei „erledigt“ gezeigt).
    DateTime? uploadedAt;
    for (final f in info.ownFiles) {
      final d = parseOwnFileTime(f.time);
      if (d != null && (uploadedAt == null || d.isAfter(uploadedAt))) {
        uploadedAt = d;
      }
    }

    String long(DateTime d) =>
        '${formatDate(t, t.uploadHeroDate, d)} · ${formatDate(t, 'HH:mm', d)}';

    final caps = upperFor(
      t,
      done
          ? t.uploadDoneCaps
          : deadline != null
          ? t.uploadDueCaps
          : t.uploadKind,
    );
    final String? big = done
        ? (uploadedAt != null
              ? long(uploadedAt)
              : cleanOwnFileTime(info.ownFiles.last.time))
        : deadline != null
        ? long(deadline)
        : null;

    String waiting(DateTime until, {required bool left}) {
      final (n, unit) = uploadWaitingTime(until, now);
      return switch (unit) {
        UploadWaitUnit.day =>
          left ? t.uploadLeftDays(n) : t.uploadStartsDays(n),
        UploadWaitUnit.hour =>
          left ? t.uploadLeftHours(n) : t.uploadStartsHours(n),
        UploadWaitUnit.minute =>
          left ? t.uploadLeftMinutes(n) : t.uploadStartsMinutes(n),
      };
    }

    // Abgegeben (auch bei „beliebig oft“ nach der Frist): nicht „Frist
    // vorbei“ (Prüfung 28.10.26).
    final String? pill =
        done || (info.ownFiles.isNotEmpty && info.isPastDeadline(now))
        ? t.uploadDoneChip
        : info.isBeforeStart(now)
        ? waiting(start!, left: false)
        : info.isPastDeadline(now)
        ? t.uploadOverdue
        : !info.open
        ? t.uploadClosed
        : deadline != null
        ? waiting(deadline, left: true)
        : null;

    double? progress;
    if (done) {
      progress = uploadedAt != null && start != null && deadline != null
          ? _share(start, deadline, uploadedAt)
          : 1;
    } else if (start != null && deadline != null) {
      progress = _share(start, deadline, now);
    }

    final String? meta = done
        ? (deadline != null
              ? t.uploadDeadlineWas(_shortWithTime(t, deadline))
              : null)
        : start == null
        ? null
        : info.isBeforeStart(now)
        ? t.uploadStarts(_shortWithTime(t, start))
        : t.uploadSince(_shortWithTime(t, start));

    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: _card(k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(caps, style: k.dateCaps)),
              if (pill != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.s,
                    vertical: Sp.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: done ? kid.tint : k.p.change.bg,
                    borderRadius: BorderRadius.circular(Rad.pill),
                  ),
                  child: Text(
                    pill,
                    style: k.tileCaption.copyWith(
                      color: done ? kid.onTint : k.p.change.ink,
                    ),
                  ),
                ),
            ],
          ),
          if (big != null) ...[
            const SizedBox(height: Sp.xs),
            Text(big, style: k.planNowSubject),
          ],
          if (progress != null) ...[
            const SizedBox(height: Sp.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.bar),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: Sz.progress,
                backgroundColor: k.p.inset,
                color: done ? kid.accent : k.p.muted,
              ),
            ),
          ],
          if (meta != null) ...[
            const SizedBox(height: Sp.s),
            Text(meta, style: k.cardMeta),
          ],
        ],
      ),
    );
  }
}

/// Anteil von [at] zwischen [from] und [to], 0…1.
double _share(DateTime from, DateTime to, DateTime at) {
  final total = to.difference(from).inSeconds;
  if (total <= 0) return 1;
  return (at.difference(from).inSeconds / total).clamp(0, 1).toDouble();
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sz.iconSmall, color: k.p.muted),
          const SizedBox(width: Sp.xs),
          Flexible(
            child: Text(
              label,
              style: k.cardMeta.copyWith(color: k.p.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Endung als Marke links in der Dateizeile („PDF“).
class _ExtBadge extends StatelessWidget {
  const _ExtBadge(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toUpperCase()
        : '';
    return Container(
      width: Sz.avatar,
      height: Sz.avatar,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(Sp.xs),
      decoration: BoxDecoration(
        color: k.p.inset,
        borderRadius: BorderRadius.circular(Rad.row),
      ),
      child: ext.isEmpty
          ? Icon(Icons.insert_drive_file_outlined, color: k.p.muted)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ext,
                maxLines: 1,
                style: k.tileCaption.copyWith(color: k.p.ink),
              ),
            ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.name,
    required this.meta,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.muted = false,
  });

  final String name;
  final String meta;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Gelöschte Dateien (Löschdatum erreicht): Name in Nebenschrift.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return DecoratedBox(
      decoration: _card(k),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.card),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.m,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                _ExtBadge(name),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: muted
                            ? k.tileTitle.copyWith(color: k.p.faint)
                            : k.tileTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: k.cardMeta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kompakte Zeile „Datei oder Foto hinzufügen“. Ursache (Rückmeldung
/// 27.10.26): Die große Fläche aus Entwurf 3 nahm mehr Platz als nötig –
/// jetzt eine Zeile wie die Dateien darunter.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.title, required this.meta, this.onTap});
  final String title;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return DecoratedBox(
      decoration: _card(k),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Sp.m),
            child: Row(
              children: [
                Container(
                  width: Sz.avatar,
                  height: Sz.avatar,
                  decoration: BoxDecoration(
                    color: k.p.inset,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: onTap == null ? k.p.faint : k.p.onNavSelected,
                    size: Sz.navIcon,
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: k.tileTitle),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: k.cardMeta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard(this.text, {this.strong = false});
  final String text;

  /// Text der Lehrkraft in Fließschrift, Hinweise der App in Nebenschrift.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: _card(k),
      child: SelectableText(text, style: strong ? k.body : k.cardMeta),
    );
  }
}
