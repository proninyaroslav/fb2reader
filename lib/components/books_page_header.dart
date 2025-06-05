import 'package:flutter/material.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/style/text.dart';

class BooksPageHeader extends StatefulWidget {
  final String title;
  final BooksSort sort;
  final ValueChanged<String?> onSearch;
  final ValueChanged<BooksSort> onSortChanged;

  const BooksPageHeader({
    super.key,
    required this.title,
    required this.sort,
    required this.onSearch,
    required this.onSortChanged,
  });

  @override
  State<BooksPageHeader> createState() => _BooksPageHeaderState();
}

class _BooksPageHeaderState extends State<BooksPageHeader> {
  bool _searchMode = false;
  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    if (_searchMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: TextField(
          onChanged: widget.onSearch,
          autofocus: true,
          focusNode: focusNode,
          decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              isDense: true,
              border: const UnderlineInputBorder(),
              focusedBorder: const UnderlineInputBorder(),
              hintText: "Поиск",
              maintainHintHeight: true,
              prefix: const Icon(
                Icons.search,
                size: 18.0,
              ),
              suffix: IconButton(
                onPressed: () {
                  widget.onSearch(null);
                  setState(() => _searchMode = false);
                },
                icon: const Icon(Icons.close, size: 18.0),
              )),
        ),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 24, 16),
            child: Text24(
              text: widget.title,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _searchMode = true);
                  focusNode.requestFocus();
                },
                icon: const Icon(Icons.search),
              ),
              PopupMenuButton<BooksSort>(
                  initialValue: widget.sort,
                  onSelected: widget.onSortChanged,
                  icon: const Icon(Icons.tune),
                  itemBuilder: (context) => BooksSort.values
                      .map((item) {
                        final title = item.toLocalizedString();
                        if (title == null) {
                          return null;
                        } else {
                          return PopupMenuItem(value: item, child: Text(title));
                        }
                      })
                      .nonNulls
                      .toList())
            ],
          )
        ],
      );
    }
  }
}
