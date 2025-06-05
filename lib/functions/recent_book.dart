class RecentBook {
  final String title;

  RecentBook({required this.title});

  factory RecentBook.fromJson(Map<String, dynamic> json) {
    return RecentBook(
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title};
  }

  RecentBook copyWith({String? title}) =>
      RecentBook(title: title ?? this.title);
}
