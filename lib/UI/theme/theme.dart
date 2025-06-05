import 'package:flutter/material.dart';
import 'package:merlin/style/colors.dart';

ThemeData darkTheme() => ThemeData(
      colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: MyColors.blackGray,
          onPrimary: MyColors.white,
          secondary: MyColors.purple,
          onSecondary: MyColors.darkGray,
          error: Colors.red,
          onError: Colors.red,
          surface: MyColors.blackGray,
          onSurface: Colors.white,
          scrim: MyColors.grayAch),
      textTheme: const TextTheme(
          //text10
          labelSmall: TextStyle(
              color: MyColors.bgWhite,
              fontFamily: 'Tektur',
              fontSize: 24,
              fontWeight: FontWeight.bold),
          //text24
          titleLarge: TextStyle(
              color: MyColors.bgWhite,
              fontFamily: 'Tektur',
              fontSize: 24,
              fontWeight: FontWeight.bold),
          //text22
          displayLarge: TextStyle(
              color: MyColors.bgWhite,
              fontFamily: 'Tektur',
              fontSize: 22,
              fontWeight: FontWeight.bold),
          //text20
          labelMedium: TextStyle(
              color: MyColors.bgWhite,
              fontFamily: 'Tektur',
              fontSize: 20,
              fontWeight: FontWeight.bold),
          //Text11
          bodySmall: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 11,
              fontWeight: FontWeight.bold),
          //Text14
          bodyLarge: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 14,
              fontWeight: FontWeight.normal),
          //Text18
          titleMedium: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 18,
              fontWeight: FontWeight.normal),
          //Text12
          titleSmall: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 12,
              fontWeight: FontWeight.normal),
          //Text7
          displaySmall: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.black,
              fontSize: 10,
              fontWeight: FontWeight.normal),
          //Text16
          displayMedium: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(
              fontFamily: 'Roboto',
              color: MyColors.bgWhite,
              fontSize: 16,
              fontWeight: FontWeight.normal),
          headlineSmall: TextStyle(
              fontFamily: 'Tektur',
              color: MyColors.bgWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
            backgroundColor: const WidgetStatePropertyAll(MyColors.blackBt),
            textStyle:
                const WidgetStatePropertyAll(TextStyle(color: MyColors.white))),
      ),
      iconTheme: const IconThemeData(color: MyColors.white),
      //dataTableTheme: DataTableThemeData(headingCellCursor: MaterialStateColor.resolveWith(states){return MyColors.darkGray;})
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStateColor.resolveWith((states) => MyColors.darkGray),
        dataRowColor:
            WidgetStateColor.resolveWith((states) => MyColors.darkGray),
      ),
    );

ThemeData purpleButton() => ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          elevation: null,
          backgroundColor: const WidgetStatePropertyAll(MyColors.purple),
          textStyle:
              const WidgetStatePropertyAll(TextStyle(color: MyColors.white))),
    ));

ThemeData grayButton() => ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        elevation: null,
        backgroundColor: WidgetStatePropertyAll(MyColors.grey.withOpacity(0.3)),
      ),
    ));

ThemeData lightTheme() => ThemeData(
    colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: MyColors.white,
        onPrimary: MyColors.white,
        secondary: MyColors.purple,
        onSecondary: MyColors.darkGray,
        error: Colors.red,
        onError: Colors.red,
        surface: MyColors.white,
        onSurface: Colors.black,
        scrim: MyColors.whiteAch),
    textTheme: const TextTheme(
        labelSmall: TextStyle(
            color: MyColors.bgWhite,
            fontFamily: 'Tektur',
            fontSize: 24,
            fontWeight: FontWeight.bold),
        //text24
        titleLarge: TextStyle(
            color: MyColors.black,
            fontFamily: 'Tektur',
            fontSize: 24,
            fontWeight: FontWeight.bold),
        //text22
        displayLarge: TextStyle(
            color: MyColors.black,
            fontFamily: 'Tektur',
            fontSize: 22,
            fontWeight: FontWeight.bold),
        //Text11
        bodySmall: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold),
        //Text14
        bodyLarge: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 14,
            fontWeight: FontWeight.normal),
        //Text14.1
        labelLarge: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 14,
            fontWeight: FontWeight.normal),
        //Text18
        titleMedium: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 18,
            fontWeight: FontWeight.normal),
        //text20
        labelMedium: TextStyle(
            color: MyColors.bgWhite,
            fontFamily: 'Tektur',
            fontSize: 20,
            fontWeight: FontWeight.bold),
        //Text12
        titleSmall: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 14,
            fontWeight: FontWeight.normal),
        //Text7
        displaySmall: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.bgWhite,
            fontSize: 10,
            fontWeight: FontWeight.normal),
        //Text16
        displayMedium: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            color: MyColors.black,
            fontSize: 16,
            fontWeight: FontWeight.normal),
        headlineSmall: TextStyle(
            fontFamily: 'Tektur',
            color: MyColors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          backgroundColor: const WidgetStatePropertyAll(MyColors.bgWhite),
          textStyle:
              const WidgetStatePropertyAll(TextStyle(color: MyColors.black))),
    ),
    iconTheme: const IconThemeData(color: MyColors.black),
    //dataTableTheme: DataTableThemeData(headingCellCursor: MaterialStateColor.resolveWith(states){return MyColors.darkGray;})
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateColor.resolveWith((states) => MyColors.white),
      dataRowColor: WidgetStateColor.resolveWith((states) => MyColors.white),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: MyColors.black,
      selectionColor: MyColors.whiteAch,
      selectionHandleColor: MyColors.purple,
    ));

ButtonStyle getButtonStyle(BuildContext context, {bool isPressed = false}) {
  final currentTheme = Theme.of(context);
  Color backgroundColor;
  Color textColor;

  if (currentTheme.brightness == Brightness.light) {
    backgroundColor = isPressed ? MyColors.purple : MyColors.white;
    textColor = isPressed ? MyColors.white : MyColors.black;
  } else {
    backgroundColor = isPressed ? MyColors.purple : MyColors.darkGray;
    textColor = isPressed ? MyColors.white : MyColors.black;
  }

  return ButtonStyle(
    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(backgroundColor),
    textStyle: WidgetStateProperty.all(TextStyle(color: textColor)),
  );
}
