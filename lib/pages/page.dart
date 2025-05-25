// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:merlin/UI/icon/custom_icon.dart';
import 'package:merlin/UI/router.dart';
import 'package:merlin/components/svg/svg_asset.dart';
import 'package:merlin/domain/scan_books_task.dart';
import 'package:merlin/domain/workmanager.dart';
import 'package:merlin/functions/helper.dart';
import 'package:merlin/pages/achievements/achievements.dart';
import 'package:merlin/pages/books/books.dart';
import 'package:merlin/pages/books/books_cubit.dart';
import 'package:merlin/pages/profile/profile.dart';
import 'package:merlin/pages/profile/profile_view_model.dart';
import 'package:merlin/pages/recent/bookloader.dart';
import 'package:merlin/pages/recent/books_recent_cubit.dart';
import 'package:merlin/pages/recent/recent.dart';
import 'package:merlin/pages/statistic/statistic.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:workmanager/workmanager.dart';

final GlobalKey _one = GlobalKey();
final GlobalKey _two = GlobalKey();
final GlobalKey _three = GlobalKey();
final GlobalKey _four = GlobalKey();
final GlobalKey _five = GlobalKey();
bool _isShowCasesShown = false;
bool _isRecentShowCasesShown = false;

class AppPage extends StatefulWidget {
  const AppPage({super.key});

  @override
  Page createState() => Page();

  static Future<void> startShowCase(BuildContext context) async {
    if (!_isShowCasesShown && await firstRun()) {
      _isShowCasesShown = true;
      ShowCaseWidget.of(context).startShowCase([_one, _two, _three, _four]);
    }
  }

  static Future<void> startRecentPageShowCase(BuildContext context) async {
    if (!_isRecentShowCasesShown && await firstRun()) {
      _isRecentShowCasesShown = true;
      await Future.delayed(const Duration(milliseconds: 500));
      ShowCaseWidget.of(context).startShowCase([_five]);
    }
  }
}

class Page extends State<AppPage> {
  int _selectedPage = 0;
  String bookName = '';
  BuildContext? myContext;

  late Future<http.Response> versionResp;

  static const List<Widget> _widgetOptions = <Widget>[
    // LoadingScreen(),
    BooksPage(),
    RecentPage(),
    AchievementsPage(),
    StatisticPage(),
  ];
  StreamSubscription? _wmStreamSubscription;
  final _booksCubit = BooksCubit();
  final _booksRecentCubit = BooksRecentCubit();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Workmanager().registerPeriodicTask(
          ScanBooksTask.periodicTaskId, ScanBooksTask.name,
          frequency: const Duration(days: 1));
      compute(runScanBooksTask, RootIsolateToken.instance!);
    });

    _wmStreamSubscription = wmScanBooksStream?.listen((stateIndex) async {
      final state = ScanBooksTaskState.values[stateIndex];
      switch (state) {
        case ScanBooksTaskState.hasNewBooks:
          _booksCubit.load(force: true);
        default:
          return;
      }
    });

    getBookName();
    super.initState();
  }

  @override
  void dispose() {
    _wmStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getBookName();
  }

  Future<void> getBookName() async {
    final prefs = await SharedPreferences.getInstance();
    bookName = prefs.getString('fileTitle') ?? '';

    /*if(DateTime.now().millisecondsSinceEpoch - (prefs.getInt("allowed") ?? 0) > 2628000000) {
      final url = Uri.parse('https://app.merlin.su/version.json');
      http.get(url, headers: {"User-Agent": "Merlin/1.0"}).then(
            (response) {
          if (response.statusCode == 200) {
            final jsonResponse = json.decode(response.body);
            if (jsonResponse != null && jsonResponse['version'] != '1.5.1') {
              WidgetsBinding.instance.addPostFrameCallback((_) =>
                  showDialog(
                    barrierDismissible: true,
                    barrierLabel: '',
                    builder: (context) {
                      final themeProvider = Provider.of<ThemeProvider>(context);

                      return AlertDialog(
                        content: Text(jsonResponse['text'], style: Theme
                            .of(context)
                            .textTheme
                            .displayLarge),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true)
                                  .pop(); // dismisses only the dialog and returns nothing
                              prefs.setInt("allowed", DateTime.now().millisecondsSinceEpoch);
                            },
                            child: Text('Закрыть', style: TextStyle(color: themeProvider.isDarkTheme ? Colors.white : Colors.black),),
                          ),
                          TextButton(
                            onPressed: () {
                              launchUrlString(jsonResponse['url']);// dismisses only the dialog and returns nothing
                            },
                            child: Text('Обновить', style: TextStyle(color: themeProvider.isDarkTheme ? Colors.white : Colors.black)),
                          ),
                        ],
                      );
                    },
                    context: context,
                  ));
            }
          } else {
            return [];
          }
        },
      );
    }*/
  }

  void onSelectTab(int index) async {
    //if (index == _selectedPage) return;
    setState(() {
      profile = false;
      _widgetOptions[index];
      _selectedPage = index;
    });
    // if (index == 0) {
    //   await ImageLoader().loadImage();
    //   final prefs = await SharedPreferences.getInstance();
    //   bool check = prefs.getBool('success') ?? false;
    //   if (check) {
    //     await Navigator.pushNamed(context, RouteNames.reader);
    //   }
    //   setState(() {
    //     profile = false;
    //     _selectedPage = 1;
    //     _widgetOptions[1];
    //   });
    // }
  }

  bool profile = false;
  final BookLoader imageLoader = BookLoader();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _booksCubit),
        BlocProvider.value(value: _booksRecentCubit)
      ],
      child: Stack(
        children: [
          ShowCaseWidget(
            builder: (context) {
              myContext = context;
              return Scaffold(
                appBar: AppBar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0.5,
                  title: GestureDetector(
                    onTap: () {
                      setState(() {
                        profile = true;
                      });
                    },
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6, right: 16),
                          child: SvgPicture.asset(
                            SvgAsset.merlinLogo,
                          ),
                        ),
                        const Text24(text: 'Merlin'),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: _selectedPage,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    BottomNavigationBarItem(
                      icon: Showcase(
                        key: _one,
                        title: 'Книги',
                        description: "Вы находитесь в списке ваших книг.\n"
                            "- Для листания вперед нажимайте на правый, левый и нижний край экрана. Для листания назад, нажимайте на верхний край экрана. Так же можно двигать текст книги свайпом вверх или вниз.\n"
                            "- При нажатии на центр экрана появляются верхний и нижний колонтитулы.",
                        disableMovingAnimation: true,
                        onToolTipClick: () {
                          ShowCaseWidget.of(context).completed(_one);
                        },
                        child: const Icon(
                          CustomIcons.bookOpen,
                        ),
                      ),
                      label: 'Книги',
                    ),
                    BottomNavigationBarItem(
                      icon: Showcase(
                        key: _two,
                        title: 'Последние книги',
                        description:
                            'Здесь находится список последних открытых книг',
                        disableMovingAnimation: true,
                        onToolTipClick: () {
                          ShowCaseWidget.of(context).completed(_two);
                        },
                        child: const Icon(
                          CustomIcons.clock,
                        ),
                      ),
                      label: 'Последнее',
                    ),
                    BottomNavigationBarItem(
                      icon: Showcase(
                          key: _three,
                          description:
                              "На вкладке достижения можно увидеть заслуженные вами Ачивки.\n"
                              "В дальнейшем наличие Ачивок будет давать дополнительные преимущества при использовании наших приложений.",
                          disableMovingAnimation: true,
                          onToolTipClick: () {
                            ShowCaseWidget.of(context).completed(_three);
                          },
                          child: const Icon(CustomIcons.trophy)),
                      label: 'Достижения',
                    ),
                    BottomNavigationBarItem(
                      icon: Showcase(
                          key: _four,
                          disableMovingAnimation: true,
                          description:
                              "Статистика. На вкладке  учитывается количество страниц в режиме чтения и в режиме Слово, которые вы прочитали за разные промежутки времени.\nРейтинг пользователей составляется за день, неделю, месяц, полгода, год, в разрезе города, региона, страны. Статистика попадает на сервер за прошедшие сутки и выгружается раз в 24 часа.\n"
                              "Если вы не авторизованный пользователь, вы увидите свою статистику на сервере только за 24 часа",
                          onToolTipClick: () {
                            ShowCaseWidget.of(context).completed(_four);
                          },
                          child: const Icon(CustomIcons.chart)),
                      label: 'Статистика',
                    ),
                  ],
                  onTap: (index) {
                    onSelectTab(index);
                  },
                  selectedItemColor:
                      profile == true ? MyColors.grey : MyColors.purple,
                  unselectedItemColor: MyColors.grey,
                  showUnselectedLabels: true,
                  selectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tektur',
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tektur',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                body: profile == true
                    ? ChangeNotifierProvider(
                        create: (context) => ProfileViewModel(context),
                        child: const Profile(),
                      )
                    : _widgetOptions[_selectedPage],
                floatingActionButton: profile == false
                    ? Showcase(
                        key: _five,
                        disableMovingAnimation: true,
                        description:
                            "Нажав на такую иконку вы можете продолжить читать любую ранее начатую книгу",
                        onToolTipClick: () {
                          ShowCaseWidget.of(context).completed(_five);
                        },
                        child: FloatingActionButton(
                          onPressed: () async {
                            await getBookName();
                            try {
                              // if (RecentPageState().checkBooks() == true) {
                              //   Fluttertoast.showToast(
                              //     msg: 'Нет последней книги',
                              //     toastLength: Toast.LENGTH_SHORT, // Длительность отображения
                              //     gravity: ToastGravity.BOTTOM,
                              //   ); // Расположение уведомления
                              // } else {
                              if (bookName == '') {
                                Fluttertoast.showToast(
                                  msg: 'Нет последней книги',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                );
                              } else {
                                Navigator.pushNamed(context, RouteNames.reader);
                              }
                              return;
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Нет последней книги',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                              );
                            }
                          },
                          backgroundColor: MyColors.purple,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.zero)),
                          autofocus: true,
                          child: Icon(
                            CustomIcons.bookOpen,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
