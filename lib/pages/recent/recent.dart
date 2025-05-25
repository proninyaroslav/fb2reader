import 'dart:ui';

import 'package:dynamic_height_grid_view/dynamic_height_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:merlin/UI/router.dart';
import 'package:merlin/components/books_page_header.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/pages/books/book_item.dart';
import 'package:merlin/pages/recent/bookloader.dart';
import 'package:merlin/pages/recent/books_recent_cubit.dart';
import 'package:merlin/pages/recent/books_recent_state.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() => RecentPageState();
}

class RecentPageState extends State<RecentPage> {
  final BookLoader imageLoader = BookLoader();
  final ScrollController _scrollController = ScrollController();
  Uint8List? imageBytes;
  List<ImageInfo> images = [];
  String? firstName;
  String? lastName;
  String? name;
  String? title;
  bool _isOperationInProgress = false;
  String? _searchQuery;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initData();
    });

    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString("booksRecentSort");
    if (str == null) {
      _selectedSort = BooksSort.dateAddedDesc;
    } else {
      _selectedSort = BooksSort.fromString(str);
    }
    if (mounted) {
      final cubit = context.read<BooksRecentCubit>();
      cubit.setSort(_selectedSort);
      cubit.load();
    }
  }

  bool isSended = false;

  Future<void> sendFileTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString('fileTitle', title);
    if (success == true) {
      isSended = true;
    }
  }

  void showInputDialog(BuildContext context, String yourVariable, int index,
      List<BookItem> books) {
    String updatedValue = "";

    final cubit = context.read<BooksRecentCubit>();
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
                    } else if (yourVariable == 'bookNameInput') {
                      await books[index].updateTitleInFile(updatedValue);
                      cubit.refreshBook(books[index],
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
            "Удалить из последних",
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
        final cubit = context.read<BooksRecentCubit>();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: BlocBuilder<BooksRecentCubit, BooksRecentState>(
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
        MediaQuery.of(context).size.shortestSide > 600 ? 150 * 1.5 : 150;
    double bookHeight =
        MediaQuery.of(context).size.shortestSide > 600 ? 230 * 1.5 : 230;
    int booksInWidth =
        ((MediaQuery.of(context).size.width - 2 * 18 + 10) / (bookWidth + 10))
            .floor();
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BooksRecentCubit, BooksRecentState>(
          builder: (context, state) {
            return Stack(
              children: [
                BooksPageHeader(
                  title: "Последнее",
                  sort: _selectedSort,
                  onSortChanged: (sort) async {
                    final cubit = context.read<BooksRecentCubit>();
                    cubit.setSort(sort);
                    cubit.filterAndSort();

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString("booksRecentSort", sort.name);

                    setState(() {
                      _selectedSort = sort;
                    });
                  },
                  onSearch: (query) {
                    final cubit = context.read<BooksRecentCubit>();
                    cubit.setSearchQuery(query);
                    cubit.filterAndSort();
                  },
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      switch (state) {
                        BooksRecentStateInitial() ||
                        BooksRecentStateLoading() =>
                          const CircularProgressIndicator(
                            color: MyColors.purple,
                          ),
                        BooksRecentStateLoaded(:final books)
                            when books.isEmpty =>
                          TextTektur(
                              text: "Пока вы не прочли никаких книг",
                              fontsize: 16,
                              textColor: MyColors.grey),
                        _ => const SizedBox.shrink()
                      }
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 72),
                  child: OrientationBuilder(builder: (context, orientation) {
                    switch (state) {
                      case BooksRecentStateLoaded(:final books):
                        return DynamicHeightGridView(
                          controller: _scrollController,
                          itemCount: books.length,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 20,
                          crossAxisCount: booksInWidth,
                          builder: (ctx, index) {
                            return GestureDetector(
                              key: ValueKey(books[index].title),
                              onTap: () async {
                                if (!_isOperationInProgress) {
                                  _isOperationInProgress = true;
                                  try {
                                    await sendFileTitle(books[index].title);
                                    if (isSended) {
                                      isSended = false;
                                      final cubit =
                                          context.read<BooksRecentCubit>();
                                      Navigator.of(context)
                                          .pushNamed(RouteNames.reader)
                                          .then((progress) => cubit.refreshBook(
                                              books[index],
                                              progress: progress as double));
                                    }
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
                              child: Column(
                                children: [
                                  if (books[index].imageBytes != null)
                                    Stack(
                                      alignment: Alignment.bottomCenter,
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
                                        Positioned.fill(
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              height: 50,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black
                                                        .withOpacity(0.8),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                            bottom: 10,
                                            left: 10,
                                            right: 10,
                                            child: LinearProgressIndicator(
                                              minHeight: 4,
                                              value: books[index].progress,
                                              backgroundColor: Colors.white,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(MyColors.purple),
                                            )),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    books[index].author.length > 15
                                        ? '${books[index].author.substring(0, books[index].author.length ~/ 1.5)}...'
                                        : books[index].author,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    books[index].customTitle.length > 40
                                        ? books[index].customTitle.length > 30
                                            ? '${books[index].customTitle.substring(0, books[index].customTitle.length ~/ 2.5)}...'
                                            : '${books[index].customTitle.substring(0, books[index].customTitle.length ~/ 2)}...'
                                        : books[index].customTitle,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(height: 1.2),
                                  ),
                                ],
                              ),
                            );
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
