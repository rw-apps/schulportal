import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Datumsdaten aller Sprachen, wie main.dart (initializeDateFormatting).
/// Ursache: Die neue Oberfläche formatiert Datumsangaben über DateFormat mit
/// der Sprache (lib/fork/l10n/l10n.dart, formatDate); ohne diese Daten wirft
/// DateFormat im Test LocaleDataException.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
