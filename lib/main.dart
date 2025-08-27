import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:merlin/UI/router.dart';
import 'package:merlin/UI/theme/theme.dart';
import 'package:merlin/domain/data_providers/sembast_provider.dart';
import 'package:merlin/domain/workmanager.dart';
import 'package:merlin/style/colors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

AppMetricaConfig get _config =>
    const AppMetricaConfig('122d6c68-55d1-46bf-bf45-27036d6307cf', logs: true);

Future<void> main() async {
  AppMetrica.runZoneGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppMetrica.activate(_config);

    await SembastProvider.init();
    await _initWorkmanager();

    runApp(
      ChangeNotifierProvider(
        create: (context) =>
            ThemeProvider(), // Создание экземпляра ThemeProvider
        child: const MerlinApp(),
      ),
    );
  });
}

Future<void> _initWorkmanager() async {
  final wm = Workmanager();
  await wm.initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
  initWmPorts();
}

class MerlinApp extends StatefulWidget {
  const MerlinApp({super.key});

  @override
  State<MerlinApp> createState() => _MerlinAppState();
}

class _MerlinAppState extends State<MerlinApp> {
  final _router = AppRouter();

  late final Future<AppOpenAdLoader> _appOpenAdLoader;
  AppOpenAd? _appOpenAd;
  final _adUnitId = 'demo-appopenad-yandex'; // TODO
  late final _adRequestConfiguration =
      AdRequestConfiguration(adUnitId: _adUnitId);

  static var isAdShowing = false;
  static var isColdStartAdShown = false;

  @override
  void initState() {
    super.initState();
    AppMetrica.reportEvent('My first AppMetrica event!');
    MobileAds.initialize();
    _appOpenAdLoader = _createAppOpenAdLoader();
    _loadAppOpenAd();
  }

  Future<AppOpenAdLoader> _createAppOpenAdLoader() {
    return AppOpenAdLoader.create(
      onAdLoaded: (AppOpenAd appOpenAd) {
        _appOpenAd = appOpenAd;

        if (!isColdStartAdShown) {
          _showAdIfAvailable();
          isColdStartAdShown = true;
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('Unable to load ad: $error');
      },
    );
  }

  Future<void> _loadAppOpenAd() async {
    final adLoader = await _appOpenAdLoader;
    await adLoader.loadAd(adRequestConfiguration: _adRequestConfiguration);
  }

  void _setAdEventListener({required AppOpenAd appOpenAd}) {
    appOpenAd.setAdEventListener(
        eventListener: AppOpenAdEventListener(onAdShown: () {
      // Called when an ad is shown.
      isAdShowing = true;
    }, onAdFailedToShow: (error) {
      // Called when an ad failed to show.
      isAdShowing = false;

      // Clear resources after Ad dismissed.
      _clearAppOpenAd();
      _loadAppOpenAd();
    }, onAdDismissed: () {
      // Called when an ad is dismissed.
      isAdShowing = false;

      // Clear resources.
      _clearAppOpenAd();
      _loadAppOpenAd();
    }, onAdClicked: () {
      // Called when a click is recorded for an ad.
      debugPrint('onAdClicked');
    }, onAdImpression: (data) {
      // Called when an impression is recorded for an ad.
      debugPrint('onAdImpression: $data');
    }));
  }

  Future<void> _showAdIfAvailable() async {
    var appOpenAd = _appOpenAd;
    if (appOpenAd != null && !isAdShowing) {
      _setAdEventListener(appOpenAd: appOpenAd);
      await appOpenAd.show();
      await appOpenAd.waitForDismiss();
    } else {
      _loadAppOpenAd();
    }
  }

  void _clearAppOpenAd() {
    _appOpenAd?.destroy();
    _appOpenAd = null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Merlin',
          theme: themeProvider.isDarkTheme ? darkTheme() : lightTheme(),
          initialRoute: RouteNames.splashScreen,
          routes: _router.routes,
        );
      },
    );
  }
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  set isDarkTheme(bool value) {
    _isDarkTheme = value;
    setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: value ? MyColors.blackGray : MyColors.white,
      systemNavigationBarIconBrightness:
          value ? Brightness.light : Brightness.dark,
    ));
    notifyListeners();
  }

  ThemeProvider() {
    _initAsync();
  }

  Future<void> _initAsync() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
  }

  void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    SystemChrome.setSystemUIOverlayStyle(style);
  }
}
