import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'room_code.dart';
import '../core/game_config.dart';

/// Host serving the web build. Also the domain that must serve
/// `/.well-known/assetlinks.json` for Android App Links to open the installed
/// app instead of the browser.
///
/// This is a Hosting *site* in the Firebase project, not the project itself —
/// the project is still `naamkaran-31493` and cannot be renamed, but a site can
/// be added alongside it, which is how the user-visible host became twinnn.
const twinWebHost = String.fromEnvironment(
  'TWIN_WEB_HOST',
  defaultValue: 'twinnn.web.app',
);

/// One-tap room joining.
///
/// Firebase Dynamic Links shut down on 25 August 2025, so this uses the native
/// equivalents instead: verified Android App Links on the web host, with a
/// custom scheme as the fallback that works with no hosting at all.
/// Both forms carry the same payload — the room code.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  /// Custom scheme. Works immediately, no domain verification needed, but most
  /// messaging apps will not linkify it.
  ///
  /// `twin` is a common word, so unlike the old scheme it is not inherently
  /// unique — another installed app could register it too, in which case Android
  /// shows a chooser. Acceptable because this is only the fallback; verified App
  /// Links are the primary path. Lengthen this if a collision ever shows up in
  /// the wild.
  static const scheme = 'twin';

  /// Host for https links. Override at build time with
  /// `--dart-define=TWIN_WEB_HOST=example.com`.
  static const webHost = twinWebHost;

  static const joinPath = 'join';

  final AppLinks _appLinks;

  final _codes = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Room codes extracted from incoming links.
  Stream<String> get incomingRoomCodes => _codes.stream;

  /// Begins listening. Returns the code from the link that cold-started the
  /// app, if any.
  Future<String?> start() async {
    if (_started) return null;
    _started = true;

    // On web there is no plugin channel and no "incoming link" event — the page
    // URL *is* the link, so read it directly. This is what makes a shared
    // https://host/join?code=ABCDE land straight in the room.
    if (kIsWeb) {
      return parseRoomCode(Uri.base);
    }

    try {
      _sub = _appLinks.uriLinkStream.listen((uri) {
        final code = parseRoomCode(uri);
        if (code != null) _codes.add(code);
      }, onError: (Object e) => debugPrint('deep link stream error: $e'));
      final initial = await _appLinks.getInitialLink();
      return initial == null ? null : parseRoomCode(initial);
    } catch (e) {
      // Deep links are a convenience; manual code entry still works.
      debugPrint('deep links unavailable: $e');
      return null;
    }
  }

  /// Accepts every shape we generate:
  ///   twin://join?code=ABCDE
  ///   twin://join/ABCDE
  ///   https://twinnn.web.app/join?code=ABCDE
  ///   https://twinnn.web.app/join/ABCDE
  static String? parseRoomCode(Uri uri) {
    final candidates = <String>[];

    final query = uri.queryParameters['code'] ?? uri.queryParameters['room'];
    if (query != null) candidates.add(query);

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) candidates.add(segments.last);

    // twin://ABCDE puts the code in the authority. Only consider the host
    // for the custom scheme — for an https URL the host is a domain, and
    // treating it as a candidate code would be wrong on any host we do not own.
    if (uri.scheme == scheme && uri.host.isNotEmpty) candidates.add(uri.host);

    for (final candidate in candidates) {
      final normalized = RoomCode.normalize(candidate);
      if (RoomCode.isValid(normalized)) return normalized;
    }
    return null;
  }

  static Uri webJoinUri(String code) =>
      Uri.https(webHost, '/$joinPath', {'code': code});

  static Uri schemeJoinUri(String code) =>
      Uri(scheme: scheme, host: joinPath, queryParameters: {'code': code});

  /// Message body for the out-of-app handshake (WhatsApp, SMS, whatever).
  static String shareMessage(
    String code, {
    String? fromName,
    GameConfig? config,
  }) {
    final who = (fromName == null || fromName.trim().isEmpty)
        ? 'Someone'
        : fromName.trim();
    final buffer = StringBuffer();
    if (config != null && config.hasCustomStart) {
      buffer.writeln('$who challenged you to TWIN!');
      buffer.writeln(
        'Can you bridge "${config.startWordA}" and "${config.startWordB}"?',
      );
    } else if (config != null && config.hasTheme) {
      buffer.writeln('$who challenged you to a ${config.theme} TWIN!');
      buffer.writeln('Can you think of the same word?');
    } else {
      buffer.writeln('$who challenged you to TWIN!');
      buffer.writeln('Can you think of the same word?');
    }
    buffer.writeln();
    buffer.writeln('Tap to play: ${webJoinUri(code)}');
    buffer.write('Room code: $code');
    return buffer.toString();
  }

  void dispose() {
    _sub?.cancel();
    _codes.close();
  }
}
