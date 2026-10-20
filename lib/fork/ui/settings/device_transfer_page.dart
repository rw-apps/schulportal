import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SimpleKeyPair;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/fork/start.dart' show firstSupportedHomePath;
import 'package:lanis/fork_identity.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';

import '../../device_transfer.dart';
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../onboarding/onboarding_kit.dart';
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
class _Scanner extends StatefulWidget {
  const _Scanner({required this.onCode, this.status});

  final void Function(String code) onCode;
  final String? status;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  MobileScannerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                debugTransferScanner?.call(widget.onCode) ??
                MobileScanner(
                  controller: _controller ??= MobileScannerController(
                    formats: const [BarcodeFormat.qrCode],
                  ),
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue;
                      if (raw != null) widget.onCode(raw);
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
          widget.status ?? t.devScanning,
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

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final key = await newTransferKey();
    final offer = await offerCode(key);
    final check = await checkCode(parseOffer(offer)!);
    if (!mounted) return;
    setState(() {
      _key = key;
      _offer = offer;
      _check = check;
    });
  }

  Future<void> _onCode(String code) async {
    if (_opening || _data != null) return;
    if (!_chunks.add(code)) return;
    setState(() {});
    if (!_chunks.complete) return;
    _opening = true;
    final p = await openPayload(_chunks.blob, _key!);
    final parsed = p == null ? null : parseDevicePayload(p);
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (parsed == null) {
        _error = context.t.devWrongKey;
      } else {
        _data = parsed;
        _scanning = false;
      }
    });
  }

  Future<void> _apply() async {
    final data = _data!;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(accountsProvider.notifier);
      final before = await ref.read(accountsProvider.future);
      bool known(TransferAccount a) => before.any(
        (b) =>
            b.schoolID == a.schoolId &&
            b.username.toLowerCase() == a.username.toLowerCase(),
      );
      final added = <int>[];
      for (final a in data.accounts) {
        if (known(a)) continue;
        added.add(
          await notifier.add(
            schoolId: a.schoolId,
            schoolName: a.schoolName,
            username: a.username,
            password: a.password,
          ),
        );
      }
      final all = await ref.read(accountsProvider.future);
      applyTransferValues(ref.read(lanisDatabaseProvider), data.settings, all);
      settingsRevision.value++;
      if (!mounted) return;
      if (widget.firstSetup) {
        acceptPrivacyPolicy(ref.read(sharedOverAccountSettingsProvider));
        final first = added.isNotEmpty ? added.first : all.first.localId;
        final ok = await ref
            .read(authControllerProvider.notifier)
            .loginWithAccount(first);
        if (!mounted) return;
        if (ok) {
          context.go(firstSupportedHomePath(ref));
          return;
        }
      }
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
                detail: a.username,
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
          onPressed: _busy || (widget.firstSetup && !_privacy) ? null : _apply,
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
  List<AccountSummary> _accounts = const [];
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
    if (_receiver != null) return;
    final pub = parseOffer(code);
    if (pub == null) return;
    final check = await checkCode(pub);
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;
    setState(() {
      _receiver = pub;
      _check = check;
      _accounts = accounts;
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(lanisDatabaseProvider);
      final accounts = <TransferAccount>[];
      for (final a in _accounts) {
        final full = await db.getAccount(a.localId);
        if (full == null) continue;
        accounts.add(
          TransferAccount(
            schoolId: full.schoolID,
            schoolName: full.schoolName,
            username: full.username,
            password: full.password,
          ),
        );
      }
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
        _cycle = Timer.periodic(const Duration(milliseconds: 1600), (_) {
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
              label: t.devWhatAccounts(_accounts.length),
              detail: _accounts.map((a) => a.username).join(', '),
            ),
            SettingsRow(icon: Icons.tune, label: t.devWhatSettings),
          ],
        ),
        const SizedBox(height: Sp.l),
        OnbButton(
          label: t.devSend,
          onPressed: _busy || _accounts.isEmpty ? null : _send,
        ),
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
