import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/file_operations.dart' as fo;

import '../../data_storage.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../settings/settings_widgets.dart';
import '../nav.dart';

/// „Dateien der Schule“ (dateispeicher.php, Wunsch 20.10.26): oben die
/// neuen Dateien, darunter die Ordner; ein Ordner öffnet dieselbe Seite.
///
/// Ursache für [load] von außen: Die Seite lässt sich so ohne Portal prüfen
/// (Tests, Bildschirmfotos). Öffnen einer Datei lädt sie mit der Sitzung
/// des Kontos (file_operations.dart, launchFile) – wie Dateien im Kurs.
class StoragePage extends StatefulWidget {
  const StoragePage({
    super.key,
    required this.title,
    required this.load,
    this.subtitle = '',
    this.onOpenFile,
    this.onOpenFolder,
  });

  final String title;
  final String subtitle;
  final Future<StorageView> Function() load;
  final void Function(StorageFile file)? onOpenFile;
  final void Function(StorageFolder folder)? onOpenFolder;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  StorageView? _view;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final v = await widget.load();
      if (mounted) {
        setState(() {
          _view = v;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final v = _view;
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(left: Sp.xs, top: Sp.xl, bottom: Sp.s),
      child: Text(title, style: k.section),
    );
    final body = <Widget>[
      if (v == null && _error == null)
        const Padding(
          padding: EdgeInsets.only(top: Sp.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (v == null && _error != null) ...[
        const SizedBox(height: Sp.xl),
        Text(t.storageLoadError, style: k.body, textAlign: TextAlign.center),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() => _error = null);
              _reload();
            },
            child: Text(t.retry, style: k.link),
          ),
        ),
      ],
      if (v != null && v.isEmpty) ...[
        const SizedBox(height: Sp.xl),
        Text(t.storageEmpty, style: k.body, textAlign: TextAlign.center),
      ],
      if (v != null && v.newFiles.isNotEmpty) ...[
        section(t.storageNew),
        for (final f in v.newFiles)
          _FileTile(file: f, fresh: true, onTap: widget.onOpenFile),
      ],
      if (v != null && v.files.isNotEmpty) ...[
        section(t.storageFiles),
        for (final f in v.files) _FileTile(file: f, onTap: widget.onOpenFile),
      ],
      if (v != null && v.folders.isNotEmpty) ...[
        section(t.storageFolders),
        for (final f in v.folders)
          _Tile(
            icon: Icons.folder_outlined,
            title: f.name,
            detail: [
              if (f.desc.isNotEmpty) f.desc,
              if (f.files != null)
                f.files == 0 ? t.storageNoFiles : t.storageFileCount(f.files!),
            ].join(' · '),
            onTap: widget.onOpenFolder == null
                ? null
                : () => widget.onOpenFolder!(f),
          ),
      ],
    ];
    // Kopf fest wie alle Unterseiten (SettingsScaffold → PinnedPage).
    return SettingsScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      onRefresh: _reload,
      children: body,
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, this.fresh = false, this.onTap});

  final StorageFile file;
  final bool fresh;
  final void Function(StorageFile file)? onTap;

  static IconData iconFor(String ext) => switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' || 'odt' || 'txt' => Icons.description_outlined,
    'xls' || 'xlsx' || 'ods' || 'csv' => Icons.table_chart_outlined,
    'ppt' || 'pptx' || 'odp' => Icons.slideshow_outlined,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'heic' => Icons.image_outlined,
    'zip' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: iconFor(file.extension),
      title: file.name,
      detail: [
        if (file.note.isNotEmpty) file.note,
        if (file.changed.isNotEmpty) file.changedDay,
        if (file.size.isNotEmpty) file.size,
      ].join(' · '),
      fresh: fresh,
      trailing: Icons.download_outlined,
      onTap: onTap == null ? null : () => onTap!(file),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.detail = '',
    this.fresh = false,
    this.trailing = Icons.chevron_right,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool fresh;
  final IconData trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.p.change;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Material(
        color: fresh ? tone.bg : k.p.card,
        borderRadius: BorderRadius.circular(Rad.signal),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.signal),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                Icon(icon, size: Sz.navIcon, color: fresh ? tone.ink : k.p.ink),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: k.planSubject(fresh ? tone.ink : k.p.ink),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          style: k.planMeta(fresh ? tone.ink : k.p.muted),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(trailing, size: Sz.icon, color: k.p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mit der Sitzung des Kontos im Rahmen (FamilyMember.scope über
/// pushFullScreen).
class LiveStoragePage extends ConsumerWidget {
  const LiveStoragePage({super.key, this.folder, this.subtitle = ''});

  /// null = Startordner.
  final StorageFolder? folder;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider).asData?.value;
    final t = context.t;
    return StoragePage(
      title: folder?.name ?? t.storageTitle,
      subtitle: subtitle,
      load: () async {
        if (session == null) throw NoConnectionException();
        return loadStorage(session, folder?.id ?? 0);
      },
      onOpenFile: (f) => fo.launchFile(
        context,
        fo.DownloadableFile(
          name: f.name,
          size: f.size.isEmpty ? null : f.size,
          url: Uri.parse(f.url),
        ),
        () {},
      ),
      onOpenFolder: (f) => pushFullScreen<void>(
        context,
        (_) => LiveStoragePage(folder: f, subtitle: subtitle),
      ),
    );
  }
}
