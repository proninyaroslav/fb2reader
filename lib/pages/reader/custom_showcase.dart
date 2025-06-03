import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:merlin/components/svg/svg_asset.dart';

const _kTextColor =
    Color.from(alpha: 0.85, red: 0.604, green: 0.271, blue: 0.816);

class CustomShowcase extends StatefulWidget {
  final Widget Function(BuildContext) builder;

  const CustomShowcase({super.key, required this.builder});

  @override
  State<CustomShowcase> createState() => _CustomShowcaseState();
}

class _CustomShowcaseState extends State<CustomShowcase> {
  final _slides = [
    const _FirstSlide(),
    const _SecondSlide(),
    const _ThirdSlide(),
  ];
  int _currentSlide = 0;
  bool _show = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_currentSlide == _slides.length - 1) {
            setState(() {
              _show = false;
            });
          } else {
            setState(() {
              _currentSlide += 1;
            });
          }
        },
        child: Stack(
          children: [
            if (_show) ...[
              IgnorePointer(child: widget.builder(context)),
              _slides[_currentSlide]
            ] else
              widget.builder(context),
          ],
        ));
  }
}

class _Container extends StatelessWidget {
  static const borderSide = BorderSide(color: _kTextColor, width: 2);

  final Widget child;
  final BoxBorder? border;

  const _Container({required this.child, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color.from(
              alpha: 0.85, red: 0.851, green: 0.851, blue: 0.851),
          border: border ?? const BoxBorder.fromBorderSide(borderSide)),
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: child,
      ),
    );
  }
}

class _Text extends StatelessWidget {
  final String text;

  const _Text({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.displayMedium!.copyWith(
            color: _kTextColor,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _FirstSlide extends StatelessWidget {
  const _FirstSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cc) {
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: cc.maxHeight / 6,
            bottom: cc.maxHeight / 6,
            width: 100,
            child: _Container(child: _buildChild('swipe\n\nшрифт')),
          ),
          Positioned(
            left: 100,
            right: 100,
            top: cc.maxHeight / 6,
            bottom: cc.maxHeight / 6,
            child: _Container(
              border: BoxBorder.fromSTEB(
                  top: _Container.borderSide, bottom: _Container.borderSide),
              child: _buildChild('swipe\n\nпрокрутка\nтекста'),
            ),
          ),
          Positioned(
            right: 0,
            top: cc.maxHeight / 6,
            bottom: cc.maxHeight / 6,
            width: 100,
            child: _Container(child: _buildChild('swipe\n\nшрифт')),
          )
        ],
      );
    });
  }

  Widget _buildChild(String text) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(SvgAsset.arrowLong),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: _Text(text: text),
          ),
          RotatedBox(
              quarterTurns: 2, child: SvgPicture.asset(SvgAsset.arrowLong)),
        ],
      );
}

class _SecondSlide extends StatelessWidget {
  const _SecondSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final leftAndRight = _Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: _Text(text: 'листать вперед\n\ntap'),
          ),
          RotatedBox(
              quarterTurns: 2, child: SvgPicture.asset(SvgAsset.arrowShort)),
        ],
      ),
    );
    final top = _Container(
        border: BoxBorder.fromSTEB(top: _Container.borderSide),
        child: const _Text(text: 'tap\n\nлистать\nназад'));
    final bottom = _Container(
      border: BoxBorder.fromSTEB(
          top: _Container.borderSide, bottom: _Container.borderSide),
      child: const _Text(text: 'tap\n\nполный\nэкран'),
    );

    return LayoutBuilder(builder: (context, cc) {
      final topPadding = MediaQuery.of(context).padding.top;
      const bottomPadding = 45.0;
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: topPadding,
            bottom: bottomPadding,
            width: 100,
            child: leftAndRight,
          ),
          Positioned(
            left: 100,
            right: 100,
            top: topPadding,
            height: cc.maxHeight / 5,
            child: top,
          ),
          Positioned(
            top: cc.maxHeight / 4,
            bottom: cc.maxHeight / 4,
            left: 100,
            right: 100,
            child: bottom,
          ),
          Positioned(
            right: 0,
            top: topPadding,
            bottom: bottomPadding,
            width: 100,
            child: leftAndRight,
          ),
        ],
      );
    });
  }
}

class _ThirdSlide extends StatelessWidget {
  const _ThirdSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cc) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Stack(
        children: [
          Positioned(
            left: 100,
            right: 100,
            top: topPadding,
            height: cc.maxHeight / 2,
            child: _Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: _Text(text: 'swipe\n\nподсказка\nперевода'),
                  ),
                  RotatedBox(
                      quarterTurns: 2,
                      child: SvgPicture.asset(SvgAsset.arrowLong)),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
