import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SimpleKeyPair;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/features/auth/auth_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/fork_identity.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';

import '../../device_transfer.dart';
import '../../error_log.dart';
import '../../kid_name.dart';
import '../../l10n/l10n.dart';
import '../../onboarding/onboarding_kit.dart';
import '../../onboarding/onboarding_pages.dart'
    show NotifyIntroPage, notifyAskedDuringSetup;
import '../../settings_transfer.dart';
import '../kit.dart';
import '../live/live_data.dart' show settingsRevision;
import 'settings_widgets.dart';
import 'transfer_page.dart';

/// „Auf neues Gerät übertragen“ (device_transfer.dart, Wunsch 20.10.26):
/// Wahl, ob dieses Gerät das neue oder das alte ist; dazu die bisherige
/// Übertragung nur der Eingaben per Datei.
class DeviceTransferPage extends StatelessWidget {
  const DeviceTransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return SettingsScaffold(
      title: t.devTitle,
      children: [
        const SizedBox(height: Sp.s),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
          child: Text(t.devIntro, style: k.body),
        ),
        const SizedBox(height: Sp.l),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.qr_code_2,
              label: t.devIsNew,
              detail: t.devIsNewDetail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeviceReceivePage(),
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.qr_code_scanner,
              label: t.devIsOld,
              detail: t.devIsOldDetail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DeviceSendPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.l),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.insert_drive_file_outlined,
              label: t.devFileOnly,
              detail: t.transferDetail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TransferPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Bausteine ----------------------------------------------------------------

/// QR-Code auf weißem Grund (auch im dunklen Design gut lesbar).
class TransferQr extends StatelessWidget {
  const TransferQr({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width - 2 * Sp.page - 2 * Sp.l)
        .clamp(200.0, 340.0);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(Sp.l),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Rad.box),
        ),
        child: QrImageView(
          data: data,
          size: size,
          errorCorrectionLevel: QrErrorCorrectLevel.L,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// Prüfcode groß zum Vergleichen.
class _CheckCode extends StatelessWidget {
  const _CheckCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Column(
      children: [
        Text(upperFor(context.t, context.t.devCheck), style: k.dateCaps),
        Text(code, style: k.greeting),
      ],
    );
  }
}

/// Nur für Tests und Abnahmebilder: ersetzt die Kamera (dort gibt es keine).
@visibleForTesting
Widget Function(void Function(String code) onCode)? debugTransferScanner;

/// Kamera mit Rahmen; [onCode] für jeden gelesenen QR-Code.
///
/// Eigener Controller mit höherer Auflösung (1920 × 1080). Ursache
/// (Rückmeldung 20.10.26): Ohne Angabe wertet Android nur 640 × 480 aus
/// (mobile_scanner_controller.dart, cameraResolution) – zu wenig für einen
/// vom Bildschirm abgelesenen Daten-Code. Weil MobileScanner mit eigenem
/// Controller den App-Lebenszyklus nicht mehr selbst behandelt
/// (mobile_scanner.dart: `if (widget.controller == null) addObserver`),
/// hält und startet [_ScannerState] die Kamera selbst – sonst liefe sie im
/// Hintergrund weiter. Grenze: Nur QR-Codes; die Auflösung gilt nur auf
/// Android, sonst wählt das Gerät.
class _Scanner extends StatefulWidget {
  const _Scanner({required this.onCode, this.status});

  final void Function(String code) onCode;
  final String? status;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> with WidgetsBindingObserver {
  MobileScannerController? _controller;

  MobileScannerController get _camera =>
      _controller ??= MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        cameraResolution: const Size(1920, 1080),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(c.start());
      case AppLifecycleState.inactive:
        unawaited(c.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onCode = widget.onCode;
    final status = widget.status;
    final k = Kit.of(context);
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rad.box),
          child: AspectRatio(
            aspectRatio: 1,
            child:
                debugTransferScanner?.call(onCode) ??
                MobileScanner(
                  controller: _camera,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue;
                      if (raw != null) onCode(raw);
                    }
                  },
                  errorBuilder: (c, e) => Container(
                    color: k.p.inset,
                    padding: const EdgeInsets.all(Sp.xl),
                    alignment: Alignment.center,
                    child: Text(
                      t.devCameraError,
                      style: k.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: Sp.m),
        Text(
          status ?? t.devScanning,
          style: k.meta,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---- Neues Gerät -------------------------------------------------------------

/// Das NEUE Gerät: Schlüssel zeigen, dann die Daten des alten Geräts scannen
/// und übernehmen. [firstSetup]: aus der Willkommensseite – dann gehört die
/// Zustimmung zum Datenschutz dazu, und danach geht es in die App.
class DeviceReceivePage extends ConsumerStatefulWidget {
  const DeviceReceivePage({super.key, this.firstSetup = false});

  final bool firstSetup;

  @override
  ConsumerState<DeviceReceivePage> createState() => _DeviceReceivePageState();
}

class _DeviceReceivePageState extends ConsumerState<DeviceReceivePage> {
  SimpleKeyPair? _key;
  String? _offer;
  String? _check;
  bool _scanning = false;
  final _chunks = ChunkCollector();
  bool _opening = false;
  ({List<TransferAccount> accounts, Map<String, Map<String, String>> settings})?
  _data;
  String? _error;
  bool _privacy = false;
  bool _busy = false;

  /// Konten, die schon auf diesem Gerät sind (transferAccountKey); sie
  /// werden übersprungen, ihre Eingaben aber zusammengeführt.
  Set<String> _existing = const {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final key = await newTransferKey();
      final offer = await offerCode(key);
      final check = await checkCode(parseOffer(offer)!);
      if (!mounted) return;
      setState(() {
        _key = key;
        _offer = offer;
        _check = check;
      });
    } catch (e, st) {
      // Ursache: Ohne Fang drehte sich der Ladekreis endlos.
      ErrorLog.instance.record('fork/geraet-schluessel', e, st);
      if (mounted) setState(() => _error = context.t.transferFailed);
    }
  }

  Future<void> _onCode(String code) async {
    if (_opening || _data != null) return;
    if (!_chunks.add(code)) return;
    setState(() => _error = null);
    if (!_chunks.complete) return;
    _opening = true;
    final p = await openPayload(_chunks.blob, _key!);
    final parsed = p == null ? null : parseDevicePayload(p);
    final existing = parsed == null
        ? const <String>{}
        : {
            for (final a in await ref.read(accountsProvider.future))
              transferAccountKey(a.schoolID, a.username),
          };
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (parsed == null) {
        // Neu sammeln, sonst lehnte ChunkCollector.add dieselben Codes ab.
        _chunks.reset();
        _error = context.t.devWrongKey;
      } else {
        _data = parsed;
        _existing = existing;
        _scanning = false;
      }
    });
  }

  /// Rückfrage „Passwort für … übernehmen?“; true = übernehmen.
  Future<bool> _askPassword(String name) async {
    final t = context.t;
    final k = Kit.of(context);
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.devPasswordTitle(name)),
        content: Text(t.devPasswordText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.devPasswordKeep, style: k.link),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.devPasswordTake),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  bool _known(TransferAccount a) =>
      _existing.contains(transferAccountKey(a.schoolId, a.username));

  Future<void> _apply() async {
    if (_busy) return;
    final data = _data!;
    // Alles aus ref VOR dem ersten await lesen. Ursache: Während der
    // Ersteinrichtung baut der Router (router.dart, _AuthListenable) bei
    // jeder Kontoänderung neu auf; diese Seite liegt per Navigator.push über
    // /welcome und kann dabei verschwinden – danach wäre ref ungültig.
    final db = ref.read(lanisDatabaseProvider);
    final accounts = ref.read(accountsProvider.notifier);
    final auth = ref.read(authControllerProvider.notifier);
    final shared = ref.read(sharedOverAccountSettingsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Erst zustimmen, dann Konten anlegen – wie das Anmeldeformular
      // (auth.dart). Ursache (Prüfung 20.10.26): resolveAuthRedirect leitet
      // Konten ohne Zustimmung nach /privacy-policy um; dabei verschwand
      // diese Seite mitten in der Übernahme (Konten angelegt, Eingaben und
      // Anmeldung fehlten, erneutes Anmelden meldete „Konto existiert“).
      if (widget.firstSetup) acceptPrivacyPolicy(shared);
      final added = <int>[];
      // Schon vorhandene Konten mit anderem Passwort: einzeln fragen
      // (Entscheidung 27.10.26). Ursache: Bisher übernahm die Übertragung
      // das Passwort still nicht – genau dann, wenn es auf dem alten Gerät
      // geändert worden war. Still überschreiben wäre ebenso falsch: Das
      // neuere Passwort kann auf diesem Gerät liegen.
      final local = await db.listAccounts();
      final differ = <(int id, String name, String password)>[];
      for (final a in data.accounts) {
        if (!_known(a)) continue;
        final key = transferAccountKey(a.schoolId, a.username);
        for (final l in local) {
          if (transferAccountKey(l.schoolID, l.username) != key) continue;
          final have = (await db.getAccount(l.localId))?.password;
          if (have != null && have != a.password) {
            final kid = storedKidName(TypedSettings.account(db, l.localId));
            differ.add((l.localId, kid.isEmpty ? a.username : kid, a.password));
          }
        }
      }
      for (final (id, name, pw) in differ) {
        if (!mounted) return;
        if (await _askPassword(name)) await accounts.updatePassword(id, pw);
      }
      for (final a in data.accounts) {
        if (_known(a)) continue;
        added.add(
          await accounts.add(
            schoolId: a.schoolId,
            schoolName: a.schoolName,
            username: a.username,
            password: a.password,
            accountType: a.accountType,
          ),
        );
      }
      applyTransferValues(db, data.settings, await db.listAccounts());
      settingsRevision.value++;
      if (widget.firstSetup && added.isNotEmpty) {
        await _askNotifications();
        // Ab hier führt der Router: loginWithAccount setzt „authenticating“,
        // resolveAuthRedirect schickt /welcome nach /startup und von dort
        // zur Startseite oder zum Fehlerblatt (StartupScreen). Diese Seite
        // wird dabei entfernt – deshalb danach nichts mehr.
        await auth.loginWithAccount(added.first);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.t.devApplied)));
      Navigator.of(context).maybePop();
    } catch (e, st) {
      ErrorLog.instance.record('fork/geraet-uebernehmen', e, st);
      if (mounted) setState(() => _error = context.t.transferFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Benachrichtigungen erklären, dann fragen (NotifyIntroPage) – wie nach
  /// dem Anmeldeformular. Ursache: Sonst fragte StartupScreen ohne
  /// Erklärung, weil der Weg nach dem Anmelden über /startup führt.
  Future<void> _askNotifications() async {
    notifyAskedDuringSetup = true;
    try {
      if (await Permission.notification.isGranted || !mounted) return;
    } catch (_) {
      return; // Kein Plattformkanal (Tests).
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) =>
            NotifyIntroPage(onDone: () => Navigator.of(page).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final data = _data;
    final children = <Widget>[];
    if (data != null) {
      children.addAll([
        const SizedBox(height: Sp.l),
        Text(t.devReceived, style: k.sheetTitle),
        const SizedBox(height: Sp.m),
        SettingsGroup(
          children: [
            for (final a in data.accounts)
              SettingsRow(
                icon: Icons.person_outline,
                label: a.schoolName.isEmpty ? '${a.schoolId}' : a.schoolName,
                detail: _known(a)
                    ? '${a.username} · ${t.devAlready}'
                    : a.username,
              ),
            SettingsRow(icon: Icons.tune, label: t.devWhatSettings),
          ],
        ),
        if (widget.firstSetup) ...[
          const SizedBox(height: Sp.m),
          InkWell(
            onTap: () => setState(() => _privacy = !_privacy),
            child: Row(
              children: [
                Checkbox(
                  value: _privacy,
                  onChanged: (v) => setState(() => _privacy = v ?? false),
                ),
                Expanded(child: Text(t.devPrivacy, style: k.body)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => safeLaunchUrl(
                Uri.parse(forkPrivacyPolicyUrl),
                context: context,
                mode: LaunchMode.externalApplication,
              ),
              child: Text(t.privacy, style: k.link),
            ),
          ),
        ],
        const SizedBox(height: Sp.l),
        OnbButton(
          label: t.devApply,
          onPressed:
              _busy ||
                  (widget.firstSetup &&
                      (!_privacy || data.accounts.every(_known)))
              ? null
              : _apply,
        ),
      ]);
    } else if (_scanning) {
      children.addAll([
        const SizedBox(height: Sp.s),
        Text(upperFor(t, t.devStep2), style: k.dateCaps),
        Text(t.devScanData, style: k.sheetTitle),
        const SizedBox(height: Sp.m),
        _Scanner(
          onCode: _onCode,
          status: _chunks.total > 1
              ? t.devScanProgress(_chunks.received, _chunks.total)
              : null,
        ),
        // Prüfcode auch hier: Wer zu früh auf „scannen“ tippt, braucht ihn
        // noch zum Vergleich auf dem alten Gerät.
        if (_check != null)
          Text(
            '${t.devCheck} $_check',
            style: k.meta,
            textAlign: TextAlign.center,
          ),
      ]);
    } else {
      children.addAll([
        const SizedBox(height: Sp.s),
        Text(upperFor(t, t.devStep1), style: k.dateCaps),
        Text(t.devShowTitle, style: k.sheetTitle),
        const SizedBox(height: Sp.m),
        if (_offer == null)
          const Padding(
            padding: EdgeInsets.all(Sp.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          TransferQr(data: _offer!),
          const SizedBox(height: Sp.m),
          _CheckCode(code: _check!),
        ],
        const SizedBox(height: Sp.m),
        Text(t.devShowHint, style: k.meta),
        const SizedBox(height: Sp.l),
        OnbButton(
          label: t.devScanData,
          icon: Icons.qr_code_scanner,
          onPressed: _offer == null
              ? null
              : () => setState(() => _scanning = true),
        ),
      ]);
    }
    if (_error != null) {
      children.addAll([
        const SizedBox(height: Sp.m),
        Text(_error!, style: k.body.copyWith(color: k.p.cancel.ink)),
      ]);
    }
    return SettingsScaffold(
      title: widget.firstSetup ? t.devFromOther : t.devIsNew,
      children: children,
    );
  }
}

// ---- Altes Gerät -------------------------------------------------------------

/// Das ALTE Gerät: Schlüssel des neuen Geräts scannen, Prüfcode vergleichen,
/// verschlüsselte Daten als QR-Code(s) zeigen (mehrere wechseln von selbst).
class DeviceSendPage extends ConsumerStatefulWidget {
  const DeviceSendPage({super.key});

  @override
  ConsumerState<DeviceSendPage> createState() => _DeviceSendPageState();
}

class _DeviceSendPageState extends ConsumerState<DeviceSendPage> {
  Uint8List? _receiver;
  String? _check;
  bool _reading = false;

  /// Zum Senden vorbereitet: alle Konten (für die Eingaben), davon die mit
  /// gespeichertem Passwort, und die Namen der übrigen.
  List<AccountSummary> _accounts = const [];
  List<TransferAccount> _sendable = const [];
  List<String> _noPassword = const [];
  List<String>? _codes;
  int _shown = 0;
  Timer? _cycle;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    // _reading: onDetect meldet denselben Code mehrmals je Sekunde.
    if (_receiver != null || _reading) return;
    final pub = parseOffer(code);
    if (pub == null) return;
    _reading = true;
    try {
      final db = ref.read(lanisDatabaseProvider);
      final check = await checkCode(pub);
      final accounts = await ref.read(accountsProvider.future);
      final sendable = <TransferAccount>[];
      final noPassword = <String>[];
      for (final a in accounts) {
        final full = await db.getAccount(a.localId);
        // Ursache: getAccount liefert '' (database.dart _rowToClearText),
        // wenn der sichere Speicher nichts hat – das neue Gerät hätte sonst
        // ein Konto ohne Passwort gespeichert.
        if (full == null || full.password.isEmpty) {
          noPassword.add(a.username);
          continue;
        }
        sendable.add(
          TransferAccount(
            schoolId: full.schoolID,
            schoolName: full.schoolName,
            username: full.username,
            password: full.password,
            accountType: full.accountType,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _receiver = pub;
        _check = check;
        _accounts = accounts;
        _sendable = sendable;
        _noPassword = noPassword;
      });
    } catch (e, st) {
      ErrorLog.instance.record('fork/geraet-lesen', e, st);
      if (mounted) setState(() => _error = context.t.transferFailed);
    } finally {
      _reading = false;
    }
  }

  Future<void> _send() async {
    if (_busy || _codes != null) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(lanisDatabaseProvider);
      final accounts = _sendable;
      final values = collectTransferValues(db, _accounts);
      final settings = {
        for (final e in values.entries)
          e.key: {
            for (final x in e.value.entries)
              if (x.value != null) x.key: x.value!,
          },
      };
      final codes = await sealPayload(
        buildDevicePayload(accounts, settings),
        _receiver!,
      );
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _shown = 0;
      });
      if (codes.length > 1) {
        _cycle?.cancel();
        // 1,3 s je Code: kleine Codes (transferChunkSize) liest die Kamera
        // in Bruchteilen einer Sekunde; mehr Codes sollen nicht ewig dauern.
        _cycle = Timer.periodic(const Duration(milliseconds: 1300), (_) {
          if (mounted) setState(() => _shown = (_shown + 1) % codes.length);
        });
      }
    } catch (e, st) {
      ErrorLog.instance.record('fork/geraet-senden', e, st);
      if (mounted) setState(() => _error = context.t.transferFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final codes = _codes;
    final children = <Widget>[];
    if (codes != null) {
      children.addAll([
        const SizedBox(height: Sp.s),
        Text(upperFor(t, t.devStep2), style: k.dateCaps),
        Text(t.devShowData, style: k.sheetTitle),
        const SizedBox(height: Sp.m),
        TransferQr(data: codes[_shown]),
        if (codes.length > 1) ...[
          const SizedBox(height: Sp.m),
          Text(
            t.devShowDataMany(_shown + 1, codes.length),
            style: k.meta,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Sp.l),
        OnbButton(
          label: t.devDone,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ]);
    } else if (_receiver != null) {
      children.addAll([
        const SizedBox(height: Sp.l),
        _CheckCode(code: _check!),
        const SizedBox(height: Sp.m),
        Text(t.devCompare, style: k.sheetTitle, textAlign: TextAlign.center),
        Text(t.devCompareHint, style: k.meta, textAlign: TextAlign.center),
        const SizedBox(height: Sp.l),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.key_outlined,
              label: t.devWhatAccounts(_sendable.length),
              detail: _sendable.map((a) => a.username).join(', '),
            ),
            SettingsRow(icon: Icons.tune, label: t.devWhatSettings),
          ],
        ),
        const SizedBox(height: Sp.l),
        OnbButton(
          label: t.devSend,
          onPressed: _busy || _sendable.isEmpty ? null : _send,
        ),
        if (_noPassword.isNotEmpty) ...[
          const SizedBox(height: Sp.s),
          Text(
            t.devNoPassword(_noPassword.join(', ')),
            style: k.meta,
            textAlign: TextAlign.center,
          ),
        ],
        if (_accounts.isEmpty) ...[
          const SizedBox(height: Sp.s),
          Text(t.devNoAccounts, style: k.meta, textAlign: TextAlign.center),
        ],
      ]);
    } else {
      children.addAll([
        const SizedBox(height: Sp.s),
        Text(upperFor(t, t.devStep1), style: k.dateCaps),
        Text(t.devScanOffer, style: k.sheetTitle),
        const SizedBox(height: Sp.m),
        _Scanner(onCode: _onCode),
      ]);
    }
    if (_error != null) {
      children.addAll([
        const SizedBox(height: Sp.m),
        Text(_error!, style: k.body.copyWith(color: k.p.cancel.ink)),
      ]);
    }
    return SettingsScaffold(title: t.devIsOld, children: children);
  }
}
