import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:merlin/UI/icon/custom_icon.dart';
import 'package:merlin/UI/theme/theme.dart';
import 'package:merlin/components/achievement.dart';
import 'package:merlin/components/ads/advertisement.dart';
import 'package:merlin/components/ads/network_provider.dart';
import 'package:merlin/components/button/button.dart';
import 'package:merlin/components/svg/svg_widget.dart';
import 'package:merlin/domain/data_providers/token_provider.dart';
import 'package:merlin/domain/dto/achievements/get_achievements_response.dart';
import 'package:merlin/functions/location.dart';
import 'package:merlin/functions/sendmail.dart';
import 'package:merlin/main.dart';
import 'package:merlin/pages/profile/dialogs/choose_avatar_dialog/choose_avatar_dialog.dart';
import 'package:merlin/pages/profile/profile_view_model.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

class AchievementStatus {
  Achievement achievement;
  bool isUnlocked;

  AchievementStatus(this.achievement, this.isUnlocked);
}

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePage();
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  late RewardedAdPage rewardedAdPage;
  String? selectedCountry;
  String? selectedState;
  String? selectedCity;

  String token = '';
  String firstName = 'Merlin';
  List<AchievementStatus> getAchievements = [];

  // ignore: prefer_typing_uninitialized_variables
  late var achievements;

  final networks = NetworkProvider.instance.rewardedNetworks;

  late var adUnitId = networks.first.adUnitId;
  RewardedAd? _ad;
  late final RewardedAdLoader _adLoader;
  var adRequest = const AdRequest();
  late final AdRequestConfiguration _adRequestConfiguration =
      AdRequestConfiguration(adUnitId: adUnitId);
  var isLoading = false;

  // кол-во доступных юзеру слов
  int words = 10;
  late int getWords;

  late Future<String> locationFuture;
  StreamController<String> controller = StreamController<String>();

  bool authMode = false;

  @override
  void initState() {
    super.initState();
    //initUniLinks();
    getSavedLocation().then((str) => controller.add(str));
    getTokenFromLocalStorage();
    getFirstNameFromLocalStorage();
    getWordsFromLocalStorage();
    MobileAds.initialize();
    _initAds();

    TokenProvider().onTokenChanged.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
    });
  }

  Future<void> saveWordsToLocalStorage(int wordsInput) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('words', wordsInput);

    setState(() {
      words = wordsInput;
    });
  }

  Future<void> getWordsFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    getWords = prefs.getInt('words') ?? 10;
    setState(() {
      words = getWords;
    });
  }

  Future<void> _initAds() async {
    _adLoader = await RewardedAdLoader.create(
      onAdLoaded: (RewardedAd rewardedAd) {
        setState(() {
          _ad = rewardedAd;
          isLoading = false;
        });
        _showRewardedAd();
        // logMessage('callback: rewarded ad loaded');
      },
      onAdFailedToLoad: (error) {
        setState(() {
          _ad = null;
          isLoading = false;
        });
        // logMessage('callback: rewarded ad failed to load, '
        //     'code: ${error.code}, description: ${error.description}');
      },
    );
  }

  Future<void> getTokenFromLocalStorage() async {
    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    //final prefs = await SharedPreferences.getInstance();

    String? tokenSecure;
    try {
      tokenSecure = await secureStorage.read(key: 'token');
    } catch (e) {
      tokenSecure == null;
    }
    token = '';
    if (tokenSecure != null) {
      token = tokenSecure;
    }
  }

  Future<void> _showRewardedAd() async {
    final ad = _ad;
    if (ad != null) {
      _setAdEventListener(ad);
      await ad.show();
      // logMessage('async: shown rewarded ad');
      // logMessage('async: dismissed rewarded ad, '
      // 'reward: ${reward?.amount} of ${reward?.type}');
      setState(() => _ad = null);
    }
  }

  void _setAdEventListener(RewardedAd ad) async {
    ad.setAdEventListener(eventListener: RewardedAdEventListener(
        // onAdShown: () => debugPrint("callback: rewarded ad shown."),
        // onAdFailedToShow: (error) => debugPrint(
        //     "callback: rewarded ad failed to show: ${error.description}."),
        // onAdDismissed: () => debugPrint("\ncallback: rewarded ad dismissed.\n"),
        // onAdClicked: () => debugPrint("callback: rewarded ad clicked."),
        // onAdImpression: (data) =>
        //     debugPrint("callback: rewarded ad impression: ${data.getRawData()}"),
        onRewarded: (Reward reward) async {
      await saveWordsToLocalStorage(words + 5);
      Fluttertoast.showToast(msg: 'Вам доступно ${words.toString()} слов');
    }));
  }

  Future<List<Achievement>> fetchJson() async {
    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    String? tokenSecure = await secureStorage.read(key: 'token');
    String token = '';
    if (tokenSecure != null) {
      token = tokenSecure;
    }
    final url = Uri.parse('https://app.merlin.su/account/achievements');
    final response = await http.get(
      url,
      headers: {"User-Agent": "Merlin/1.0", 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final ach = GetAchievementsResponse.fromJson(jsonResponse);
      final List<Achievement> achievements = [];
      achievements.add(ach.achievements.baby);
      achievements.add(ach.achievements.spell);
      achievements.addAll(ach.achievements.simpleModeAchievements);
      achievements.addAll(ach.achievements.wordModeAchievements);
      return achievements;
    } else {
      return [];
    }
  }

  Future<void> getAchievementsFromJson() async {
    achievements = await fetchJson();
    for (var entry in achievements) {
      getAchievements.add(AchievementStatus(entry, false));
    }
  }

  Future<void> getFirstNameFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    String? tokenSecure = await secureStorage.read(key: 'token');
    String token = '';
    if (tokenSecure != null) {
      token = tokenSecure;
    }
    if (token != '') {
      setState(() {
        var getFirstName = prefs.getString('firstName') ?? firstName;
        firstName = getFirstName;
        // debugPrint('имя из локалки $firstName');
      });
    }
  }

  Future<void> saveJsonToFile(
      Map<String, dynamic> jsonData, String filePath) async {
    try {
      final file = File(filePath);
      final directory = Directory(file.parent.path);

      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Ошибка при сохранении файла: $e');
    }
  }

  Future<void> saveCurrentTime(String fileName) async {
    final appDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    final filePath = '${appDir?.path}/Timer/$fileName.json';
    var timeNow = DateTime.now();
    await saveJsonToFile({'TimeDialog': timeNow.toIso8601String()}, filePath);
  }

  Future<DateTime?> readTimeFromJsonFile(String fileName) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/Timer/$fileName.json';
      final file = File(filePath);
      if (await file.exists()) {
        final fileContent = await file.readAsString();
        final jsonData = jsonDecode(fileContent);
        if (jsonData.containsKey('TimeDialog')) {
          return DateTime.parse(jsonData['TimeDialog']);
        }
      }
    } catch (e) {
      print('Ошибка при чтении файла: $e');
    }
    return null;
  }

  void loadAD() async {
    const String fileName = 'timeStepAD';
    var timeNow = DateTime.now();
    var timeLast = await readTimeFromJsonFile(fileName);
    if (timeLast != null) {
      var elapsedTime = timeNow.difference(timeLast);
      if (elapsedTime.inHours >= 24) {
        _adLoader.loadAd(
            adRequestConfiguration:
                const AdRequestConfiguration(adUnitId: 'R-M-10590682-1'));
        await saveCurrentTime('timeStepAD');
      } else {
        var timeLast = await readTimeFromJsonFile(fileName);
        if (timeLast != null) {
          final formattedTime = DateFormat('dd.MM.yy HH:mm')
              .format(timeLast.add(const Duration(days: 1)));

          Fluttertoast.showToast(
            msg: 'Новые слова будут доступны $formattedTime',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } else {
      _adLoader.loadAd(
          adRequestConfiguration:
              const AdRequestConfiguration(adUnitId: 'R-M-10590682-1'));
      await saveCurrentTime('timeStepAD');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (authMode) {
      authMode = false;
      getTokenFromLocalStorage();
      getFirstNameFromLocalStorage();
      getWordsFromLocalStorage();
    }
    // print('ШИРИНА');
    // print(width);
    // double aspectRatio = height/width;
    double width = MediaQuery.of(context).size.width;
    double size = 20;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final avatar = context.watch<ProfileViewModel>().storedAvatar;
    final setNewAvatar = context.read<ProfileViewModel>().setNewAvatar;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.only(left: 24, top: 24),
            child: const Row(
              children: [
                Text24(
                  text: 'Мой профиль',
                  textColor: MyColors.black,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
              child: Column(children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    avatar == null
                        ? const MerlinWidget()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.memory(
                              avatar,
                              width: 100,
                              height: 100,
                            ))
                  ],
                ),
                if (token != '')
                  Positioned(
                    bottom: -14,
                    right: MediaQuery.of(context).size.width / 2 - 48 - 24,
                    child: IconButton(
                        onPressed: () async {
                          final avatarChanged =
                              await showChooseAvatarDialog(context);
                          setNewAvatar(avatarChanged);
                        },
                        icon: Icon(
                          CustomIcons.pen,
                          size: size,
                        )),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Text24(
              text: firstName,
              textColor: MyColors.black,
            ),
            StreamBuilder(
                stream: controller.stream,
                builder:
                    (BuildContext context, AsyncSnapshot<String?> snapshot) {
                  String locationData =
                      snapshot.data ?? 'Нет данных о местоположении';
                  if (snapshot.data != null) {
                    locationData = locationData.replaceFirst(' (the)', '');
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 2 * size),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: width > 650
                                  ? 400
                                  : MediaQuery.of(context).size.width * 0.75),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text16(text: locationData),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openLocationPicker(context),
                        icon: Icon(
                          CustomIcons.pen,
                          size: size,
                        ),
                      ),
                    ],
                  );
                })
          ])),
          const SizedBox(height: 81),
          token == ''
              ? Expanded(
                  child: Column(
                    children: [
                      Theme(
                        data: purpleButton(),
                        child: Button(
                          text: 'Авторизоваться',
                          width: 312,
                          height: 48,
                          horizontalPadding: 97,
                          verticalPadding: 12,
                          textColor: MyColors.white,
                          fontSize: 14,
                          onPressed: () async {
                            final tgUrl = Uri.parse(
                                'tg://resolve?domain=merlin_auth_bot&start=1');
                            await launchUrl(tgUrl,
                                mode: LaunchMode.externalApplication);
                            authMode = true;
                            //exit(0);
                          },
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Expanded(
                        child: Align(
                            alignment: AlignmentDirectional.bottomCenter,
                            child: Theme(
                              data: themeProvider.isDarkTheme
                                  ? darkTheme()
                                  : lightTheme(),
                              child: Button(
                                  text: 'Написать нам',
                                  width: 312,
                                  height: 48,
                                  horizontalPadding: 97,
                                  verticalPadding: 12,
                                  textColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  onPressed: () {
                                    mail();
                                  }),
                            )),
                      ),
                      const SizedBox(height: 24)
                    ],
                  ),
                )
              : Expanded(
                  child: Column(
                    children: [
                      Theme(
                        data: purpleButton(),
                        child: Button(
                          text: 'Получить 5 слов',
                          width: 312,
                          height: 48,
                          horizontalPadding: 97,
                          verticalPadding: 12,
                          textColor: MyColors.white,
                          fontSize: 14,
                          onPressed: () async {
                            loadAD();
                            // Fluttertoast.showToast(msg: 'Вам доступно $words слов', toastLength: Toast.LENGTH_LONG);
                          },
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Theme(
                        data: grayButton(),
                        child: Button(
                          text: 'Убрать рекламу',
                          width: 312,
                          height: 48,
                          horizontalPadding: 97,
                          verticalPadding: 12,
                          textColor: Theme.of(context).disabledColor,
                          fontSize: 14,
                          onPressed: () {},
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Expanded(
                        child: Align(
                            alignment: AlignmentDirectional.bottomCenter,
                            child: Theme(
                              data: themeProvider.isDarkTheme
                                  ? darkTheme()
                                  : lightTheme(),
                              child: Button(
                                  text: 'Написать нам',
                                  width: 312,
                                  height: 48,
                                  horizontalPadding: 97,
                                  verticalPadding: 12,
                                  textColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  onPressed: () {
                                    mail();
                                  }),
                            )),
                      ),
                      const SizedBox(height: 24)
                    ],
                  ),
                ),
        ]),
      ),
    );
  }

  void mail() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Center(
                child: TextButton(
                    onPressed: () {
                      Clipboard.setData(
                          const ClipboardData(text: 'readermerlin@gmail.com'));
                      Fluttertoast.showToast(
                        msg: 'Почта скопирована',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                    },
                    child: const Text18(
                        text: 'readermerlin@gmail.com',
                        textColor: MyColors.black)),
              ),
              alignment: Alignment.center,
              actions: [
                Center(
                  child: Column(
                    children: [
                      TextButton(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://merlin.su');
                            if (!await launchUrl(url)) {
                              throw Exception('Ошибка');
                            }
                          },
                          child: const Text18(text: 'merlin.su')),
                      const SizedBox(height: 20),
                      Theme(
                          data: purpleButton(),
                          child: const Button(
                              text: "Написать",
                              width: 250,
                              height: 50,
                              horizontalPadding: 10,
                              verticalPadding: 10,
                              textColor: MyColors.white,
                              fontSize: 14,
                              onPressed: sendEmail,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Theme(
                          data: themeProvider.isDarkTheme
                              ? darkTheme()
                              : lightTheme(),
                          child: Button(
                              text: "Отмена",
                              width: 250,
                              height: 50,
                              horizontalPadding: 10,
                              verticalPadding: 10,
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              fontWeight: FontWeight.bold))
                    ],
                  ),
                )
              ],
            ));
  }

  Future<GeoPoint?> showSimplePickerLocation({
    required BuildContext context,
    Widget? titleWidget,
    String? title,
    TextStyle? titleStyle,
    String? textConfirmPicker,
    String? textCancelPicker,
    EdgeInsets contentPadding = EdgeInsets.zero,
    double radius = 0.0,
    GeoPoint? initPosition,
    ZoomOption zoomOption = const ZoomOption(),
    bool isDismissible = false,
    UserTrackingOption? initCurrentUserPosition,
  }) async {
    assert(title == null || titleWidget == null);
    assert(
      ((initCurrentUserPosition != null) && initPosition == null) ||
          ((initCurrentUserPosition == null) && initPosition != null),
    );
    final MapController controller = MapController(
      initMapWithUserPosition: initCurrentUserPosition,
      initPosition: initPosition,
    );
    GeoPoint? center;
    GeoPoint? old;
    GeoPoint? point = await showDialog(
      context: context,
      builder: (ctx) {
        return PopScope(
          canPop: isDismissible,
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 2.4,
            width: MediaQuery.of(context).size.height / 2,
            child: AlertDialog(
              title:
                  title != null ? Text(title, style: titleStyle) : titleWidget,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
              ),
              contentPadding: contentPadding,
              content: SizedBox(
                height: MediaQuery.of(context).size.height / 2.5,
                width: MediaQuery.of(context).size.height / 2,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: OSMFlutter(
                            controller: controller,
                            onMapMoved: (regsion) {
                              setState(() {
                                old = center;
                                center = regsion.center;
                              });
                            },
                            osmOption: OSMOption(
                              zoomOption: zoomOption,
                              isPicker: true,
                            ),
                          ),
                        ),
                        Positioned(
                          child: AnimatedCenterMarker(center: center),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    textCancelPicker ??
                        MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final center = await controller.centerMap;
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, center);
                  },
                  child: Text(
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    textConfirmPicker ??
                        MaterialLocalizations.of(context).okButtonLabel,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return point;
  }

  Future<GeoPoint?> _openLocationPicker(BuildContext context) async {
    var pickedLocation = await showSimplePickerLocation(
      context: context,
      isDismissible: true,
      title: "Выберите локацию",
      textConfirmPicker: "Выбрать",
      contentPadding: const EdgeInsets.only(bottom: 10),
      zoomOption: const ZoomOption(
        initZoom: 1,
      ),
      initPosition: GeoPoint(
        latitude: 61,
        longitude: 69,
      ),
      radius: 8.0,
    );
    if (pickedLocation != null) {
      Map<String, String> location = convertGeoPointToMap(pickedLocation);
      // print("Picked Location: $location");
      if (token == '' || token.isEmpty) {
        convertCoordsToAdress(location).then((event) {
          controller.add(event);
        }).catchError((e) => print(e));
      } else {
        convertCoordsToAdress(location).then((event) {
          controller.add(event);
        }).catchError((e) => print(e));
        await sendLocationDataToServer(location, token);
      }
    }
    return pickedLocation;
  }

  Map<String, String> convertGeoPointToMap(GeoPoint? geoPoint) {
    if (geoPoint == null) {
      return {};
    }
    return {
      'latitude': geoPoint.latitude.toString(),
      'longitude': geoPoint.longitude.toString(),
    };
  }
}
