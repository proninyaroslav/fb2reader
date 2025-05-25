import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:merlin/UI/router.dart';
import 'package:merlin/UI/theme/theme.dart';
import 'package:merlin/components/books_page_header.dart';
import 'package:merlin/components/button/button.dart';
import 'package:merlin/domain/books_repository.dart';
import 'package:merlin/domain/scan_books_task.dart';
import 'package:merlin/domain/workmanager.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/pages/books/book_item.dart';
import 'package:merlin/pages/books/books_cubit.dart';
import 'package:merlin/pages/books/books_state.dart';
import 'package:merlin/pages/page.dart';
import 'package:merlin/pages/recent/bookloader.dart';
import 'package:merlin/pages/recent/books_recent_cubit.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => BooksPageState();
}

class BooksPageState extends State<BooksPage> {
  final BooksRepository _booksRepo = BooksRepository();
  final BookLoader imageLoader = BookLoader();
  final ScrollController _scrollController = ScrollController();
  Uint8List? imageBytes;
  String? firstName;
  String? lastName;
  String? name;
  String? title;
  bool _isOperationInProgress = false;
  bool _isScanningInProgress = false;
  bool _isStoragePermissionGranted = true;
  StreamSubscription? _wmStreamSubscription;
  BooksSort _selectedSort = BooksSort.dateAddedDesc;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ],
    );

    _wmStreamSubscription = wmScanBooksStream?.listen((stateIndex) async {
      final state = ScanBooksTaskState.values[stateIndex];
      switch (state) {
        case ScanBooksTaskState.inProgress:
          setState(() {
            _isScanningInProgress = true;
          });
        default:
          setState(() {
            _isScanningInProgress = false;
          });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pref = await SharedPreferences.getInstance();
      final isGranted = await _checkStoragePermissionGranted();
      setState(() {
        _isStoragePermissionGranted = isGranted;
      });
      if (mounted) {
        if (isGranted) {
          AppPage.startShowCase(context);
        } else if (pref.getBool("isShowPermissionsDialogLater") != true) {
          final result = await showDialog<bool>(
              context: context,
              builder: (context) => _StoragePermissionDialog(onShowLater: () {
                    pref.setBool("isShowPermissionsDialogLater", true);
                  }));
          if (mounted) {
            AppPage.startShowCase(context);
          }
          if (result == true) {
            final isGranted = await _requestStoragePermission();
            if (isGranted) {
              compute(runScanBooksTask, RootIsolateToken.instance!);
            }

            setState(() {
              _isStoragePermissionGranted = isGranted;
            });
          }
        }
      }

      _initData();
    });

    super.initState();
  }

  Future<Permission> _getStoragePermission() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
      if ((info.version.sdkInt) >= 33) {
        return Permission.manageExternalStorage;
      } else {
        return Permission.storage;
      }
    } else {
      return Permission.storage;
    }
  }

  Future<bool> _checkStoragePermissionGranted() async {
    final permission = await _getStoragePermission();
    switch (await permission.status) {
      case PermissionStatus.denied:
        return false;
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.restricted:
        return false;
      case PermissionStatus.limited:
        return true;
      case PermissionStatus.permanentlyDenied:
        return false;
      case PermissionStatus.provisional:
        return true;
    }
  }

  Future<bool> _requestStoragePermission() async {
    final permission = await _getStoragePermission();
    final status = await permission.request();

    switch (status) {
      case PermissionStatus.denied:
        return false;
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.restricted:
        return false;
      case PermissionStatus.limited:
        return true;
      case PermissionStatus.permanentlyDenied:
        return false;
      case PermissionStatus.provisional:
        return true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wmStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString("booksSort");
    if (str == null) {
      _selectedSort = BooksSort.dateAddedDesc;
    } else {
      _selectedSort = BooksSort.fromString(str);
    }
    if (mounted) {
      final cubit = context.read<BooksCubit>();
      cubit.setSort(_selectedSort);
      cubit.load();
    }
  }

  bool isSaved = false;

  void showInputDialog(BuildContext context, String yourVariable, int index,
      List<BookItem> books) {
    String updatedValue = "";

    final cubit = context.read<BooksCubit>();
    final recentCubit = context.read<BooksRecentCubit>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            title: Text(yourVariable == 'authorInput'
                ? 'Изменить автора'
                : 'Изменить название'),
            content: TextField(
              onChanged: (value) {
                updatedValue = value;
              },
            ),
            actions: <Widget>[
              TextButton(
                child: const TextForTable(
                  text: 'Отмена',
                  textColor: MyColors.black,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Сохранить',
                    style: TextStyle(color: Colors.blue)),
                onPressed: () async {
                  if (updatedValue.isEmpty) {
                    Fluttertoast.showToast(
                      msg: 'Введите значение перед сохранением',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  } else {
                    if (yourVariable == 'authorInput') {
                      await books[index].updateAuthorInFile(updatedValue);

                      cubit.refreshBook(books[index], author: updatedValue);
                      recentCubit.refreshBook(books[index],
                          author: updatedValue);
                    } else if (yourVariable == 'bookNameInput') {
                      await books[index].updateTitleInFile(updatedValue);

                      cubit.refreshBook(books[index],
                          customTitle: updatedValue);
                      recentCubit.refreshBook(books[index],
                          customTitle: updatedValue);
                    }
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Offset _tapPosition = Offset.zero;

  void _getTapPosition(TapDownDetails tapPosition) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    setState(() {
      _tapPosition = renderBox.globalToLocal(tapPosition.globalPosition);
    });
  }

  void _showBlurMenu(
      BuildContext context, int index, List<BookItem> books) async {
    final RenderObject? overlay =
        Overlay.of(context).context.findRenderObject();
    final result = await showMenu(
      context: context,
      color: const Color.fromARGB(255, 73, 73, 73).withAlpha(200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          _tapPosition.dx,
          _tapPosition.dy,
          10,
          10,
        ),
        Rect.fromLTWH(
          0,
          0,
          overlay!.paintBounds.size.width,
          overlay.paintBounds.size.height,
        ),
      ),
      items: [
        const PopupMenuItem(
          value: 'change-author',
          child: Text(
            "Изменить автора",
            style: TextStyle(color: MyColors.white, fontSize: 13),
          ),
        ),
        const PopupMenuItem(
          value: 'change-title',
          child: Text(
            "Изменить название",
            style: TextStyle(color: MyColors.white, fontSize: 13),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            "Удалить",
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      ],
    );

    switch (result) {
      case 'change-author':
        showInputDialog(context, 'authorInput', index, books);
        break;
      case 'change-title':
        showInputDialog(context, 'bookNameInput', index, books);
        break;
      case 'delete':
        final cubit = context.read<BooksCubit>();
        final recentCubit = context.read<BooksRecentCubit>();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: BlocBuilder<BooksCubit, BooksState>(
                bloc: cubit,
                builder: (context, state) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    title: Text(books[index].customTitle),
                    content:
                        const Text("Вы уверены, что хотите удалить книгу?"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const TextForTable(
                          text: "Отмена",
                          textColor: MyColors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          cubit.deleteBook(books[index]);
                          recentCubit.deleteBook(books[index]);
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          "Удалить",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    double bookWidth =
        MediaQuery.of(context).size.shortestSide > 600 ? 33 * 1.5 : 33;
    double bookHeight =
        MediaQuery.of(context).size.shortestSide > 600 ? 50 * 1.5 : 50;

    final recentCubit = context.read<BooksRecentCubit>();

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BooksCubit, BooksState>(
          builder: (context, state) {
            return Stack(
              children: [
                BooksPageHeader(
                  title: "Книги",
                  sort: _selectedSort,
                  onSortChanged: (sort) async {
                    final cubit = context.read<BooksCubit>();
                    cubit.setSort(sort);
                    cubit.filterAndSort();

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString("booksSort", sort.name);

                    setState(() {
                      _selectedSort = sort;
                    });
                  },
                  onSearch: (query) {
                    final cubit = context.read<BooksCubit>();
                    cubit.setSearchQuery(query);
                    cubit.filterAndSort();
                  },
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state case BooksStateInitial() || BooksStateLoading())
                        const CircularProgressIndicator(
                          color: MyColors.purple,
                        )
                      else if (state case BooksStateLoaded(:final books)
                          when books.isEmpty)
                        if (_isScanningInProgress) ...[
                          const SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                              color: MyColors.purple,
                            ),
                          ),
                          const SizedBox(
                            width: 16.0,
                          ),
                          TextTektur(
                              text: "Добавляю ваши книги",
                              fontsize: 16,
                              textColor: MyColors.grey),
                        ] else
                          TextTektur(
                              text: "Пока вы не добавили никаких книг",
                              fontsize: 16,
                              textColor: MyColors.grey)
                      else
                        const SizedBox.shrink()
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, right: 16.0, top: 72),
                  child: OrientationBuilder(builder: (context, orientation) {
                    switch (state) {
                      case BooksStateLoaded(:final books):
                        return ListView.separated(
                          controller: _scrollController,
                          itemCount: books.length + 1,
                          separatorBuilder: (context, index) => const SizedBox(
                            height: 8.0,
                          ),
                          itemBuilder: (ctx, index) {
                            if (index == 0) {
                              if (_isStoragePermissionGranted) {
                                return const SizedBox.shrink();
                              } else {
                                return _RequestPermissionButton(
                                    onClick: () async {
                                  await _requestStoragePermission();
                                  final isGranted =
                                      await _checkStoragePermissionGranted();
                                  if (isGranted) {
                                    compute(runScanBooksTask,
                                        RootIsolateToken.instance!);
                                  }
                                  setState(() {
                                    _isStoragePermissionGranted = isGranted;
                                  });
                                });
                              }
                            } else {
                              index = index - 1;
                              return GestureDetector(
                                key: ValueKey(books[index].title),
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  if (!_isOperationInProgress) {
                                    _isOperationInProgress = true;
                                    try {
                                      await recentCubit
                                          .saveToRecent(books[index]);
                                      final cubit = context.read<BooksCubit>();
                                      Navigator.of(context)
                                          .pushNamed(RouteNames.reader)
                                          .then((progress) {
                                        cubit.refreshBook(books[index],
                                            progress: progress as double);
                                        recentCubit.refreshBook(books[index],
                                            progress: progress);
                                      });
                                    } catch (e) {
                                      // Обработка ошибок, если необходимо
                                    } finally {
                                      _isOperationInProgress = false;
                                      // if (mounted) setState(() {});
                                    }
                                  }
                                },
                                onTapDown: (position) {
                                  _getTapPosition(position);
                                },
                                onLongPress: () {
                                  // onTapLongPressOne(context, index);
                                  _showBlurMenu(context, index, books);
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    books[index].imageBytes?.first != 0
                                        ? Image.memory(
                                            books[index].imageBytes!,
                                            width: bookWidth,
                                            height: bookHeight,
                                            fit: BoxFit.fill,
                                          )
                                        : SvgPicture.asset(
                                            'assets/icon/no_name_book.svg',
                                            width: bookWidth,
                                            height: bookHeight,
                                            fit: BoxFit.fitHeight,
                                          ),
                                    const SizedBox(width: 16.0),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              books[index].customTitle,
                                              maxLines: 1,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8.0),
                                            Text(
                                              books[index].author,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            if (books[index].sequence !=
                                                null) ...[
                                              const SizedBox(height: 8.0),
                                              _Sequence(
                                                  sequence:
                                                      books[index].sequence!)
                                            ],
                                            const SizedBox(height: 8.0),
                                            _TypeAndSize(
                                              book: books[index],
                                            ),
                                            const SizedBox(height: 8.0),
                                            LinearProgressIndicator(
                                              minHeight: 4,
                                              value: books[index].progress,
                                              backgroundColor:
                                                  MyColors.lightGray,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(MyColors.purple),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }
                          },
                        );
                      default:
                        return const SizedBox.shrink();
                    }
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sequence extends StatelessWidget {
  final BookSequence sequence;

  const _Sequence({required this.sequence});

  @override
  Widget build(BuildContext context) {
    final BookSequence(:name, :number) = sequence;
    return Text(number == null ? name : '$name №$number',
        maxLines: 1,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall);
  }
}

class _TypeAndSize extends StatelessWidget {
  final BookItem book;

  const _TypeAndSize({required this.book});

  @override
  Widget build(BuildContext context) {
    return Text('${book.bookTypeName}, ${getFileSizeStr(book.fileSize, 1)}',
        maxLines: 1,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall);
  }

  String getFileSizeStr(int bytes, int decimals) {
    if (bytes <= 0) {
      return "0 Б";
    }
    const suffixes = ["Б", "КБ", "МБ", "ГБ", "ТБ", "ПБ", "ЭБ", "ЗБ", "ЙБ"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

class _RequestPermissionButton extends StatelessWidget {
  const _RequestPermissionButton({required this.onClick});

  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: grayButton(),
        child: Button(
          text: 'Запросить разрешение на чтение',
          width: 320,
          height: 48,
          horizontalPadding: 62,
          verticalPadding: 12,
          textColor: MyColors.black,
          fontSize: 14,
          onPressed: onClick,
          fontWeight: FontWeight.bold,
        ));
  }
}

class _StoragePermissionDialog extends StatelessWidget {
  final VoidCallback onShowLater;

  const _StoragePermissionDialog({required this.onShowLater});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        content: TextTektur(
          text: "Для чтения книг разрешите доступ на следующем экране",
          textColor: MyColors.black,
          fontsize: 16,
        ),
        actions: <Widget>[
          TextButton(
            child: const TextForTable(
              text: 'Позже',
              textColor: MyColors.black,
            ),
            onPressed: () {
              onShowLater();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Ок', style: TextStyle(color: Colors.blue)),
            onPressed: () async {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }
}
