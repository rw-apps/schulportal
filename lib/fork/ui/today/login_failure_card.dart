import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../portal_fault.dart';
import '../kit.dart';
import '../live/family.dart';
import '../login_errors.dart';

/// Hinweis auf „Heute“: ein weiteres Konto konnte nicht angemeldet werden.
/// Mit „Erneut versuchen“ und – bei abgelehntem Passwort – „Passwort
/// ändern“. Ursache: Vorher fehlte das Kind still (Rückmeldung 19.10.26).
class LoginFailureCard extends ConsumerWidget {
  const LoginFailureCard({super.key, required this.failure, this.onRetry});

  final FamilyFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = Kit.of(context);
    final t = context.t;
    final e = failure.error;
    final msg = loginErrorText(t, e);
    final a = failure.account;
    final who = a.schoolName.isNotEmpty ? a.schoolName : a.username;
    final kind = portalFault(e).kind;
    final wrong =
        kind == FaultKind.wrongCredentials || kind == FaultKind.incomplete;
    // Rot nur, wenn das Konto selbst ein Problem hat; ist das Portal
    // gestört, grau wie die übrigen Hinweise (HintCard, KitPalette.todo).
    // Ursache (Rückmeldung 22.10.26): Eine rote Karte wirkte bei einer
    // Störung des Portals wie ein Fehler der App.
    final tone = portalFault(e).notTheApp ? k.p.todo : k.p.cancel;
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.s, Sp.s),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                portalFault(e).notTheApp
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
                size: Sz.navIcon,
                color: tone.ink,
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.loginFailedFor(who, msg.title),
                      style: k.boxStrong(tone),
                    ),
                    Text(msg.text, style: k.boxText(tone)),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (wrong)
                TextButton(
                  onPressed: () async {
                    final ok = await changeAccountPassword(
                      context,
                      ref,
                      a.localId,
                    );
                    if (ok) onRetry?.call();
                  },
                  child: Text(t.passwordChange, style: k.link),
                ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(t.loginRetry, style: k.link),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
