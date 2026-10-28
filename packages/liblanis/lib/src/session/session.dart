import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import '../applets/definition.dart';
import '../config.dart';
import '../connection/connection_checker.dart';
import '../exceptions.dart';
import '../models/account.dart';
import '../models/account_types.dart';
import 'cryptor.dart';

/// Authenticated SPH HTTP session for one account.
class LanisSession {
  final ClearTextAccount account;
  final LanisConfig config;
  final ConnectionChecker connectionChecker;

  late Cryptor cryptor = Cryptor();
  late CookieJar jar;
  final Dio dio = Dio();
  Timer? preventLogoutTimer;
  Future<void>? _authentication;

  Map<String, String> userData = {};
  AccountType? _accountType;
  List<dynamic> travelMenu = [];

  AccountType? get accountTypeOrNull => _accountType ?? account.accountType;

  AccountType get accountType => accountTypeOrNull!;

  LanisSession({
    required this.account,
    required this.config,
    required this.connectionChecker,
  });

  Future<void> prepareDio() async {
    jar = CookieJar();

    if (config.httpAdapter != null) {
      dio.httpClientAdapter = config.httpAdapter!;
    }
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.data != null) {
            connectionChecker.status = ConnectionStatus.connected;
          } else {
            connectionChecker.status = ConnectionStatus.disconnected;
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            connectionChecker.status = ConnectionStatus.disconnected;
          }
          return handler.next(error);
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.data is String) {
            final contentType = response.headers.value('content-type');
            if (contentType != null && contentType.contains('text/html')) {
              response.data = cryptor.decryptEncodedTags(response.data);
            }
          }
          return handler.next(response);
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.addAll({'User-Agent': config.userAgent});
          return handler.next(options);
        },
      ),
    );
    dio.options.followRedirects = false;
    dio.options.connectTimeout = const Duration(seconds: 8);
    dio.options.validateStatus = (status) =>
        status != null && (status == 200 || status == 302 || status == 503);
  }

  Future<void> authenticate({
    bool withoutData = false,
    String? withLoginUrl,
  }) async {
    // Fork: Neuanmeldung je Sitzung nur einmal gleichzeitig („single
    // flight“). Ursache (Prüfung 27.10.26, liblanis-Befund 3): Scheitert ein
    // Abruf, meldet sich AppletParser.fetchData neu an – bei mehreren
    // Modulen gleichzeitig also mehrfach. 0.1.4 reihte diese Aufrufe nur
    // hintereinander: jede weitere Anmeldung leerte erneut die Cookies
    // (_authenticate, jar.deleteAll) und tauschte den Schlüssel, während die
    // Abrufe nach der ersten Anmeldung schon liefen; bei falschem Passwort
    // zählte jeder Aufruf als eigener Fehlversuch (Sperre authErrorLocktime).
    // Jetzt warten gleichzeitige Aufrufer auf DIESELBE laufende Anmeldung und
    // bekommen deren Ergebnis bzw. deren Ausnahme.
    // Grenze: Mitgenommen wird nur, wem die laufende Anmeldung genügt – ein
    // Aufruf mit eigenem withLoginUrl, oder mit Nutzerdaten, während eine
    // Anmeldung ohne Daten läuft, wartet wie in 0.1.4 und meldet sich danach
    // selbst an. Abrufe, die beim Start einer Anmeldung schon unterwegs sind,
    // verlieren mit dem Leeren der Cookies weiterhin ihre Sitzung; sie
    // scheitern und landen über fetchData in derselben Anmeldung.
    while (true) {
      final running = _authentication;
      if (running == null) break;
      final covered =
          withLoginUrl == null &&
          _authenticationLoginUrl == null &&
          (withoutData || !_authenticationWithoutData);
      if (covered) return running;
      try {
        await running;
      } catch (_) {
        // A previous caller's failure must not prevent this caller from retrying.
      }
    }
    final authentication = _runAuthentication(
      withoutData: withoutData,
      withLoginUrl: withLoginUrl,
    );
    _authentication = authentication;
    _authenticationWithoutData = withoutData;
    _authenticationLoginUrl = withLoginUrl;
    try {
      await authentication;
    } finally {
      if (identical(_authentication, authentication)) {
        _authentication = null;
      }
    }
  }

  bool _authenticationWithoutData = false;
  String? _authenticationLoginUrl;

  /// [_authenticate] mit der Fehler-Übersetzung von 0.1.4 – als eigene
  /// Future, damit mitwartende Aufrufer dieselbe übersetzte Ausnahme sehen.
  Future<void> _runAuthentication({
    required bool withoutData,
    String? withLoginUrl,
  }) async {
    try {
      await _authenticate(withoutData: withoutData, withLoginUrl: withLoginUrl);
    } on LanisException {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          // Fork: Die Login-Anfrage hat seit Befund 2 auch ein Sende-Limit.
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NoConnectionException();
      }
      throw UnknownException(e.message ?? e.toString());
    }
  }

  Future<void> _authenticate({
    bool withoutData = false,
    String? withLoginUrl,
  }) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    jar.deleteAll();
    dio.options.validateStatus = (status) =>
        status != null && (status == 200 || status == 302 || status == 503);

    final downCheckResponse = await dio.get(
      'https://start.schulportal.hessen.de/',
    );
    if (downCheckResponse.statusCode == 503 ||
        downCheckResponse.data.toString().contains(
          'Der Bereich der pädagogischen Organisation steht Ihnen aktuell nicht zur Verfügung.',
        )) {
      throw LanisDownException();
    }

    final loginURL = withLoginUrl ?? await getLoginURL(account, config);
    await dio.get(loginURL);

    preventLogoutTimer?.cancel();
    preventLogoutTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => preventLogout(),
    );

    travelMenu = await getFastTravelMenu();
    if (!withoutData) {
      final response = await dio.get(
        'https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userData',
      );
      final document = parse('${response.data ?? ''}');
      userData = parseUserData(document);
      // Fork (Befund 11): eine schon erkannte Kontoart nicht durch null
      // ersetzen, wenn die Seite diesmal kein bekanntes Symbol zeigt.
      _accountType = parseAccountType(document) ?? _accountType;
    }

    await cryptor.initialize(dio);
  }

  Future<void> deAuthenticate() async {
    preventLogoutTimer?.cancel();
    try {
      await dio.get('https://start.schulportal.hessen.de/index.php?logout=all');
    } catch (_) {}
    jar.deleteAll();
  }

  static Future<String> getLoginURL(
    ClearTextAccount acc,
    LanisConfig config,
  ) async {
    final dioHttp = Dio();
    final cookieJar = CookieJar(ignoreExpires: true);
    if (config.httpAdapter != null) {
      dioHttp.httpClientAdapter = config.httpAdapter!;
    }

    try {
      dioHttp.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            response.headers.forEach((name, values) {
              if (name.toLowerCase() == 'set-cookie') {
                for (var i = 0; i < values.length; i++) {
                  values[i] = values[i].replaceAll('HttpOnly=1', 'HttpOnly');
                }
              }
            });
            return handler.next(response);
          },
        ),
      );
      dioHttp.interceptors.add(CookieManager(cookieJar));
      dioHttp.options.followRedirects = false;
      // Fork: Zeitlimits wie die App für die Sitzung (lib/fork/
      // session_guard.dart: forkReceiveTimeout 30 s, forkSendTimeout 60 s).
      // Ursache (Prüfung 27.10.26, liblanis-Befund 2): 0.1.2 hatte hier gar
      // kein Limit, 0.1.4 nur Verbindung und Empfang mit je 8 s und kein
      // Sende-Limit – an diese eigene Dio kommt der App-Wächter
      // (guardForkSession) nicht heran. 8 s Empfang waren für den Login-
      // Server im Mobilnetz knapp (Anmeldung scheiterte als
      // NoConnectionException), ohne Sende-Limit konnte das Absenden hängen.
      // Grenze: connectTimeout bleibt 8 s wie in prepareDio; beim Android-
      // Adapter zählen Verbindung und Empfang gemeinsam bis zu den
      // Kopfzeilen (siehe session_guard.dart).
      dioHttp.options.connectTimeout = const Duration(seconds: 8);
      dioHttp.options.receiveTimeout = const Duration(seconds: 30);
      dioHttp.options.sendTimeout = const Duration(seconds: 60);
      dioHttp.options.validateStatus = (status) =>
          status != null && (status == 200 || status == 302 || status == 503);

      final response1 = await dioHttp.post(
        'https://login.schulportal.hessen.de/?i=${acc.schoolID}',
        data: {
          'user': '${acc.schoolID}.${acc.username}',
          'user2': acc.username,
          'password': acc.password,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'User-Agent': config.userAgent},
        ),
      );

      if (response1.statusCode == 503) {
        throw LanisDownException();
      }

      if (response1.headers.value(HttpHeaders.locationHeader) != null) {
        final response2 = await dioHttp.get(
          'https://connect.schulportal.hessen.de',
        );
        return response2.headers.value(HttpHeaders.locationHeader) ?? '';
      }
      throw loginFailure('${response1.data ?? ''}');
    } finally {
      _closeDioWithoutSharedAdapter(dioHttp, config.httpAdapter);
    }
  }

  /// Fork: Ausnahme für eine Login-Antwort ohne Weiterleitung.
  ///
  /// Ursache (Prüfung 27.10.26, liblanis-Befund 6): 0.1.4 wertete JEDE
  /// solche Seite außer der Sperr-Seite als falsches Passwort. Eine
  /// Wartungs- oder Fehlerseite des Login-Servers (HTTP 200) ließ die App
  /// deshalb „Passwort falsch“ melden; die App merkt sich das Passwort dann
  /// als abgelehnt und meldet sich damit nicht mehr selbst an
  /// (lib/fork/login_guard.dart, noteLoginResult).
  ///
  /// Merkmale, in dieser Reihenfolge:
  /// 1. `#authErrorLocktime` (wie 0.1.4) → [LoginTimeoutException].
  /// 2. Das Anmeldeformular kommt zurück (`input[type=password]` oder
  ///    `input[name=password]`) oder der Text nennt „fehlgeschlagen“ →
  ///    [WrongCredentialsException]. So antwortet der Login-Server auf
  ///    abgelehnte Zugangsdaten: Er zeigt das Formular erneut.
  /// 3. Sonst nennt der Text „Wartung“ oder „nicht zur Verfügung“ →
  ///    [LanisDownException].
  /// 4. Alles andere (leer, fremde Seite) → [UnknownException].
  ///
  /// Grenze: Bewusst vorsichtig – alles, was wie das Anmeldeformular
  /// aussieht, gilt weiter als falsches Passwort, auch wenn darüber ein
  /// Wartungshinweis steht (Ankündigungen stehen oft auf der Login-Seite).
  /// Lieber einmal zu oft „Passwort falsch“ als eine Anmelde-Schleife mit
  /// einem falschen Passwort, die das Konto sperrt. Nur Seiten OHNE
  /// Formular werden jetzt anders eingeordnet.
  static LanisException loginFailure(String html) {
    final document = parse(html);
    final lockTime = document.getElementById('authErrorLocktime');
    if (lockTime != null) {
      return LoginTimeoutException(
        lockTime.text,
        'Too many failed logins. Wait ${lockTime.text}s before retrying.',
      );
    }
    final text = (document.body?.text ?? html).toLowerCase();
    final loginForm =
        document.querySelector('input[type=password]') != null ||
        document.querySelector('input[name=password]') != null;
    if (loginForm || text.contains('fehlgeschlagen')) {
      return WrongCredentialsException();
    }
    if (text.contains('wartung') || text.contains('nicht zur verfügung')) {
      return LanisDownException();
    }
    return UnknownException('Unexpected login response');
  }

  Future<void> preventLogout() async {
    final uri = Uri.parse('https://start.schulportal.hessen.de/ajax_login.php');
    String sid;
    try {
      sid = (await jar.loadForRequest(
        uri,
      )).firstWhere((element) => element.name == 'sid').value;
    } on StateError {
      return;
    }
    try {
      final response = await dio.post(
        'https://start.schulportal.hessen.de/ajax_login.php',
        data: 'name=${Uri.encodeComponent(sid)}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'x-requested-with': 'XMLHttpRequest'},
        ),
      );
      if (response.statusCode == 503) {
        connectionChecker.status = ConnectionStatus.disconnected;
      }
    } on DioException {
      return;
    }
  }

  Future<List<dynamic>> getFastTravelMenu() async {
    final response = await dio.get(
      'https://start.schulportal.hessen.de/startseite.php?a=ajax&f=apps',
    );
    return jsonDecode(response.data.toString())['entrys'] as List<dynamic>;
  }

  Map<String, String> parseUserData(Document document) {
    final userDataTableBody = document.querySelector(
      'div.col-md-12 table.table.table-striped tbody',
    );

    if (userDataTableBody == null) return {};

    final result = <String, String>{};
    for (final row in userDataTableBody.querySelectorAll('tr')) {
      // Fork: Zeilen ohne zwei Zellen überspringen, Doppelpunkt nur
      // abschneiden, wenn er da ist. Ursache (Prüfung 27.10.26,
      // liblanis-Befund 11): children[1] warf RangeError bei einer
      // Zwischenüberschrift (eine Zelle, colspan), substring(0, -1) bei
      // einer leeren ersten Zelle, und ein Schlüssel ohne „:“ verlor seinen
      // letzten Buchstaben. Der Fehler brach die ganze Anmeldung ab
      // (_authenticate). Grenze: Übersprungene Zeilen fehlen in userData.
      if (row.children.length < 2) continue;
      var key = row.children[0].text.trim();
      final value = row.children[1].text.trim();
      if (key.endsWith(':')) key = key.substring(0, key.length - 1).trim();
      if (key.isEmpty) continue;
      result[key.toLowerCase()] = value;
    }
    return result;
  }

  /// Fork: null statt Absturz bei unbekannter Kontoart.
  ///
  /// Ursache (Prüfung 27.10.26, liblanis-Befund 11): Fehlte das Symbol oben
  /// rechts (`!` → TypeError) oder war es ein anderes (UnknownException),
  /// scheiterte die ganze Anmeldung (_authenticate). Jetzt gilt dann die
  /// gespeicherte Kontoart ([accountTypeOrNull] fällt auf
  /// [ClearTextAccount.accountType] zurück). Grenze: Ist auch dort keine
  /// gespeichert, bleibt [accountTypeOrNull] null; [doesSupportFeature]
  /// nimmt dann wie bisher Schüler an. Ob die Anmeldung gültig ist, prüft
  /// weiterhin getFastTravelMenu (JSON statt Login-Seite).
  AccountType? parseAccountType(Document document) {
    final iconClassList = document
        .querySelector('.nav.navbar-nav.navbar-right>li>a>i')
        ?.classes;
    if (iconClassList == null) return null;
    if (iconClassList.contains('fa-child')) {
      return AccountType.student;
    } else if (iconClassList.contains('fa-user-circle')) {
      return AccountType.parent;
    } else if (iconClassList.contains('fa-user')) {
      return AccountType.teacher;
    }
    return null;
  }

  bool doesSupportFeature(
    AppletMeta applet, {
    AccountType? overrideAccountType,
  }) {
    final app = travelMenu
        .where((element) => element['link'].toString() == applet.appletPhpUrl)
        .singleOrNull;
    if (app == null) return false;
    return applet.supportedAccountTypes.contains(
      overrideAccountType ?? accountTypeOrNull ?? AccountType.student,
    );
  }

  Future<void> dispose() async {
    preventLogoutTimer?.cancel();
    _closeDioWithoutSharedAdapter(dio, config.httpAdapter);
  }

  /// [LanisConfig.httpAdapter] (e.g. Flutter Cronet) is shared across
  /// sessions. [Dio.close] closes the adapter — swap it out first.
  static void _closeDioWithoutSharedAdapter(
    Dio dio,
    HttpClientAdapter? shared,
  ) {
    if (shared != null && identical(dio.httpClientAdapter, shared)) {
      dio.httpClientAdapter = IOHttpClientAdapter();
    }
    dio.close(force: true);
  }
}
