import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/figma_review/care.dart';
import 'features/figma_review/core.dart';
import 'features/figma_review/daily.dart';
import 'features/figma_review/device_store.dart';
import 'features/figma_review/device_settings.dart';
import 'features/figma_review/health.dart';
import 'features/figma_review/example_account.dart';
import 'features/figma_review/health_chat_view.dart';
import 'features/figma_review/health_chat_sessions.dart';
import 'features/figma_review/screens.dart';
import 'l10n/app_localizations.dart';

/// Isolated entry point. No SDK bootstrap, account or external service session.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ReviewController(
      deviceStore: createReviewDeviceStore(
          exampleProfile: Uri.base.queryParameters['account'] == 'sample'));
  await controller.initializeDeviceStorage();
  if (Uri.base.pathSegments.firstOrNull != 'review') {
    openExampleAccount(controller, DateTime.now());
  }
  runApp(BodabReviewApp(
    controller: controller,
    showDesignDirectory: Uri.base.pathSegments.firstOrNull == 'review',
  ));
}

class BodabReviewApp extends StatefulWidget {
  const BodabReviewApp({
    super.key,
    this.initial = 'home',
    this.controller,
    this.showDesignDirectory = false,
  });
  final ReviewController? controller;
  final bool showDesignDirectory;
  final String initial;
  @override
  State<BodabReviewApp> createState() => _BodabReviewAppState();
}

class _BodabReviewAppState extends State<BodabReviewApp> {
  late final _controller =
      widget.controller ?? ReviewController(initial: widget.initial);
  late final _router = _ReviewRouter(_controller, widget.showDesignDirectory);
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;
  late int _lastSave, _lastClear;
  bool _offeredSaving = false;

  @override
  void initState() {
    super.initState();
    _lastSave = _controller.userSaveCount;
    _lastClear = _controller.clearCount;
    _controller.addListener(_observeSaves);
    _lifecycle = AppLifecycleListener(onResume: _refreshDay);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(tomorrow.difference(now), _refreshDay);
  }

  void _refreshDay() {
    if (!mounted) return;
    _scheduleMidnight();
    // Refresh calendar labels even if the tab stayed open overnight.
    _controller.update(() {});
  }

  void _observeSaves() {
    if (_lastClear != _controller.clearCount) {
      _lastClear = _controller.clearCount;
      _offeredSaving = false;
    }
    if (_lastSave == _controller.userSaveCount) return;
    _lastSave = _controller.userSaveCount;
    if (widget.controller == null ||
        _offeredSaving ||
        _controller.deviceSavingEnabled) {
      return;
    }
    _offeredSaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _controller.deviceSavingEnabled) return;
      final context = _router.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await chooseDeviceSaving(context, _controller);
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _controller.removeListener(_observeSaves);
    _router.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: '보답',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NotoSansKRReview',
            colorScheme: ColorScheme.fromSeed(seedColor: reviewGreen).copyWith(
                primary: reviewGreen,
                onSurface: reviewInk,
                surface: reviewBackground),
            scaffoldBackgroundColor: reviewBackground,
            textTheme: const TextTheme(
                bodyMedium: TextStyle(
                    fontFamily: 'NotoSansKRReview',
                    fontSize: 20,
                    height: 1.4,
                    color: reviewInk)),
            textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                    foregroundColor: reviewGreen,
                    textStyle: const TextStyle(
                        fontFamily: 'NotoSansKRReview',
                        fontSize: 18,
                        fontWeight: FontWeight.w600)))),
        routerDelegate: _router,
        routeInformationParser: const _ReviewParser(),
        builder: (_, child) =>
            ReviewScope(controller: _controller, child: child!),
      );
}

class _ReviewParser extends RouteInformationParser<String> {
  const _ReviewParser();
  static const _designPreviews = {'login', 'login_error'};

  @override
  Future<String> parseRouteInformation(RouteInformation info) async {
    final parts = info.uri.pathSegments;
    if (parts.isEmpty) return '';
    if (parts.length == 2 &&
        parts.first == 'design' &&
        _designPreviews.contains(parts.last)) {
      return parts.last;
    }
    // Bookmarks from the old sign-in flow should also start at today's home.
    return parts.length == 1 &&
            !_designPreviews.contains(parts.first) &&
            isBodabRoute(parts.first)
        ? parts.first
        : 'home';
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(
        uri: Uri(pathSegments: [
          '',
          if (_designPreviews.contains(configuration)) 'design',
          configuration
        ]),
      );
}

class _ReviewRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  _ReviewRouter(this.controller, this.showDesignDirectory) {
    controller.addListener(notifyListeners);
  }
  final ReviewController controller;
  final bool showDesignDirectory;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  String get currentConfiguration => controller.current;
  @override
  Future<void> setNewRoutePath(String configuration) async {
    if (isBodabRoute(configuration) && configuration != controller.current) {
      controller.go(configuration);
    }
  }

  @override
  Future<bool> popRoute() async {
    if (await navigatorKey.currentState?.maybePop() == true) return true;
    if (!controller.canGoBack) return false;
    controller.back();
    return true;
  }

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
            key: const ValueKey('bodab-review-shell'),
            child: _ReviewPhone(
                controller: controller,
                showDesignDirectory: showDesignDirectory)),
      ],
      onDidRemovePage: (_) {});
}

class _ReviewPhone extends StatelessWidget {
  const _ReviewPhone(
      {required this.controller, required this.showDesignDirectory});
  final bool showDesignDirectory;
  final ReviewController controller;
  Future<void> _select(BuildContext context) async {
    final key = await showModalBottomSheet<String>(
        context: context,
        sheetAnimationStyle: AnimationStyle.noAnimation,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (context) => FractionallySizedBox(
            heightFactor: 0.88,
            child: _ScreenDirectory(current: controller.current)));
    if (key != null) controller.go(key);
  }

  @override
  Widget build(BuildContext context) {
    if (controller.current == healthChatRoute) {
      final sessions = controller.model(
          () => HealthChatSessions(onChanged: () => controller.update(() {})));
      return ColoredBox(
        color: const Color(0xffe9eae6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(children: [
              if (controller.storageError != null)
                SafeArea(
                    bottom: false,
                    child: BodabStorageNotice(controller: controller)),
              Expanded(
                  child: HealthChatView(
                sessions: sessions,
                deviceSavingEnabled: controller.deviceSavingEnabled &&
                    controller.storageError == null &&
                    !controller.deviceWritePending,
                onSaveToDevice: (id) async {
                  if (controller.storageError != null) {
                    throw StateError('Device storage needs attention');
                  }
                  if (!controller.deviceSavingEnabled &&
                      !await chooseDeviceSaving(context, controller)) {
                    return;
                  }
                  if (context.mounted && controller.deviceSavingEnabled) {
                    sessions.setRetained(id, true);
                    await controller.waitForDeviceWrites();
                    if (controller.storageError != null) {
                      throw StateError('Device did not confirm saving');
                    }
                  }
                },
                onBack: () => controller.back('home'),
                onOpenAppRoute: (route) {
                  switch (route) {
                    case 'checkin':
                      startTodayCheckin(controller);
                    case 'upload':
                      openHealthUpload(controller);
                    case 'medications':
                    case 'activities':
                      controller.go(route);
                  }
                },
              )),
            ]),
          ),
        ),
      );
    }
    final spec = reviewFrames[controller.current]!;
    final page = switch (spec.group) {
      1 || 2 || 3 => buildDailyScreen(spec.base, controller),
      4 || 5 || 6 => buildHealthScreen(spec.base, controller),
      _ => buildCareScreen(spec.base, controller),
    };
    final media = MediaQuery.of(context);
    final inherited = media.textScaler;
    final scaler = spec.large && inherited.scale(20) < 40
        ? const TextScaler.linear(2)
        : inherited;
    return ColoredBox(
        color: const Color(0xffe9eae6),
        child: Center(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth:
                        showDesignDirectory || spec.large || spec.width == 360
                            ? spec.width.toDouble()
                            : 540),
                child: Scaffold(
                    backgroundColor: reviewBackground,
                    body: SafeArea(
                        child: Column(children: [
                      if (controller.storageError != null)
                        BodabStorageNotice(controller: controller)
                      else if (controller.deviceWritePending)
                        Semantics(
                          liveRegion: true,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('기기에 저장 중…'),
                          ),
                        ),
                      if (showDesignDirectory)
                        DecoratedBox(
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                    bottom: BorderSide(color: reviewLine))),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(children: [
                                  Expanded(
                                      child: Semantics(
                                          label: '현재 화면 ${spec.name}',
                                          excludeSemantics: true,
                                          child: Text(spec.name,
                                              style: const TextStyle(
                                                  fontFamily:
                                                      'NotoSansKRReview',
                                                  fontSize: 14,
                                                  color: reviewGreen,
                                                  fontWeight:
                                                      FontWeight.w600)))),
                                  TextButton.icon(
                                      onPressed: () => _select(context),
                                      icon: const Icon(Icons.grid_view_outlined,
                                          size: 17),
                                      label: const Text('화면 목록'),
                                      style: TextButton.styleFrom(
                                          textStyle: const TextStyle(
                                              fontFamily: 'NotoSansKRReview',
                                              fontSize: 14),
                                          minimumSize: const Size(44, 44))),
                                ]))),
                      Expanded(
                          child: MediaQuery(
                              data: media.copyWith(
                                  size: Size(
                                      (showDesignDirectory ||
                                                  spec.large ||
                                                  spec.width == 360
                                              ? spec.width.toDouble()
                                              : 540.0)
                                          .clamp(0, media.size.width),
                                      media.size.height),
                                  textScaler: scaler),
                              child: KeyedSubtree(
                                  key: ValueKey(controller.current),
                                  child: page))),
                    ]))))));
  }
}

class _ScreenDirectory extends StatelessWidget {
  const _ScreenDirectory({required this.current});
  final String current;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
            child: Row(children: [
              const Expanded(
                  child: Text('화면 목록',
                      style: TextStyle(
                          fontFamily: 'NotoSansKRReview',
                          fontSize: 24,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  tooltip: '목록 닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('8개 영역 · 기본 및 상태 35개 · 접근성 예시 6개',
                style:
                    TextStyle(fontFamily: 'NotoSansKRReview', fontSize: 14))),
        Expanded(
            child:
                ListView(padding: const EdgeInsets.only(bottom: 36), children: [
          for (var group = 1; group <= reviewGroups.length; group++) ...[
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Text(reviewGroups[group - 1],
                    style: const TextStyle(
                        fontFamily: 'NotoSansKRReview',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: reviewGreen))),
            for (final item
                in reviewFrames.entries.where((e) => e.value.group == group))
              ListTile(
                  selected: item.key == current,
                  title: Text(item.value.name,
                      style: const TextStyle(
                          fontFamily: 'NotoSansKRReview', fontSize: 17)),
                  trailing:
                      item.key == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, item.key)),
          ],
        ])),
      ]);
}
