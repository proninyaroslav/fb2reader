import 'package:flutter/material.dart';
//import 'package:merlin/style/colors.dart';

class Button extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final Color? buttonColor;
  final Color textColor;
  final double fontSize;
  final VoidCallback onPressed;
  final FontWeight fontWeight;

  const Button({
    required this.text,
    required this.width,
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    this.buttonColor,
    required this.textColor,
    required this.fontSize,
    required this.onPressed,
    required this.fontWeight,
    super.key,
  });

  factory Button.icon({
    required String text,
    required IconData icon,
    required double width,
    required double height,
    required double horizontalPadding,
    required double verticalPadding,
    Color? buttonColor,
    required Color textColor,
    required double fontSize,
    required VoidCallback onPressed,
    required FontWeight fontWeight,
  }) {
    return _ButtonWithIcon(
      text: text,
      icon: icon,
      width: width,
      height: height,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      textColor: textColor,
      fontSize: fontSize,
      onPressed: onPressed,
      fontWeight: fontWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        //ПРИМЕР ИСПОЛЬЗОВАНИЯ ТЕМ !!!!!!!!!!!!
        style: Theme.of(context).elevatedButtonTheme.style ??
            ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              backgroundColor: buttonColor,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
            ),
        child: Text(text,
            style: TextStyle(
                color: textColor,
                fontFamily: 'Tektur',
                fontSize: fontSize,
                fontWeight: fontWeight)),
      ),
    );
  }
}

class _ButtonWithIcon extends Button {
  final IconData icon;

  const _ButtonWithIcon({
    required super.text,
    required this.icon,
    required super.width,
    required super.height,
    required super.horizontalPadding,
    required super.verticalPadding,
    super.buttonColor,
    required super.textColor,
    required super.fontSize,
    required super.onPressed,
    required super.fontWeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        //ПРИМЕР ИСПОЛЬЗОВАНИЯ ТЕМ !!!!!!!!!!!!
        style: Theme.of(context).elevatedButtonTheme.style ??
            ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              backgroundColor: buttonColor,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
            ),
        icon: Icon(
          icon,
          size: 24.0,
          color: textColor,
        ),
        iconAlignment: IconAlignment.end,
        label: Text(text,
            style: TextStyle(
                color: textColor,
                fontFamily: 'Tektur',
                fontSize: fontSize,
                fontWeight: fontWeight)),
      ),
    );
  }
}
