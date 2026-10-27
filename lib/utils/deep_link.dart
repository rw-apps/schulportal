/// Settings paths under `/common/settings/…` und die Moodle-Route.
///
/// Fork (Prüfung 27.10.26): Die übrige `lanis://`-Deep-Link-Logik
/// (deepLinkLocationFromUri, Vorsilben-Prüfung und -Umschreibung,
/// DeepLinkErrorPage, DeepLinkPopScope) ist entfernt. Ursache: Das Manifest
/// hat seit der Sicherheitsprüfung 17.10.26 keinen `lanis://`-Filter mehr,
/// und weder router.dart noch fork/ rief diese Teile auf. Grenze: Was hier
/// bleibt, nutzen router.dart / preview_shell.dart (moodle) und
/// view/settings/settings_page_builder.dart (home).
abstract final class SettingsDeepLinks {
  static const base = '/common/settings';
  static const home = '$base/home';
  static const moodle = '/common/moodle';
}
