import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/deep_link_service.dart';
import 'state/app_session.dart';
import 'ui/app_theme.dart';
import 'ui/boot_screen.dart';
import 'ui/home_screen.dart';
import 'ui/room_launcher.dart';
import 'ui/views/onboarding_view.dart';

class TwinApp extends StatefulWidget {
  const TwinApp({super.key});

  @override
  State<TwinApp> createState() => _TwinAppState();
}

class _TwinAppState extends State<TwinApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _session = AppSession();
  final _deepLinks = DeepLinkService();

  StreamSubscription<String>? _linkSub;

  /// A code that arrived before the session finished loading.
  String? _queuedCode;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.initialize();
    _startDeepLinks();
  }

  Future<void> _startDeepLinks() async {
    _linkSub = _deepLinks.incomingRoomCodes.listen(_handleCode);
    final cold = await _deepLinks.start();
    if (cold != null) _handleCode(cold);
  }

  void _onSessionChanged() {
    final queued = _queuedCode;
    if (queued != null &&
        _session.status == SessionStatus.ready &&
        _session.onboardingDone) {
      _queuedCode = null;
      _handleCode(queued);
    }
  }

  void _handleCode(String code) {
    // An invite link waits until the player is in: a brand-new player
    // finishes onboarding (name, face, player ID) first, and only then
    // does the room open. Queued codes fire from _onSessionChanged.
    if (_session.status != SessionStatus.ready || !_session.onboardingDone) {
      _queuedCode = code;
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      _queuedCode = code;
      return;
    }
    RoomLauncher.joinAndOpen(context, _session, code);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _deepLinks.dispose();
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSession>.value(value: _session),
        Provider<DeepLinkService>.value(value: _deepLinks),
      ],
      child: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => MaterialApp(
          title: 'TWIN',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: AppTheme.fromPalette(_session.palette),
          home: const _SessionGate(),
        ),
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return switch (session.status) {
      SessionStatus.loading => BootScreen(step: session.loadingStep),
      SessionStatus.failed => BootScreen(
        step: 'Could not start',
        error: session.errorMessage,
        onRetry: session.initialize,
      ),
      SessionStatus.ready =>
        session.onboardingDone ? const HomeScreen() : const OnboardingView(),
    };
  }
}
