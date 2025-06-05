import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:merlin/components/svg/svg_asset.dart';

const _kTextColor =
    Color.from(alpha: 0.85, red: 0.604, green: 0.271, blue: 0.816);

class CustomShowcase extends StatefulWidget {
  final Widget Function(BuildContext) builder;

  const CustomShowcase({super.key, required this.builder});

  @override
  State<CustomShowcase> createState() => CustomShowcaseState();
}

class CustomShowcaseState extends State<CustomShowcase> {
  List<Widget> _slides = [];
  int _currentSlide = 0;
  bool _show = false;

  void showSlides(List<Widget> slides) {
    _slides = slides;
    setState(() {
      _currentSlide = 0;
      _show = true;
    });
  }

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
        child: FittedBox(child: child),
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

class FirstSlide extends StatelessWidget {
  const FirstSlide({super.key});

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
            child: _Container(child: _buildChild('swipe\n\nяркость')),
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

class SecondSlide extends StatelessWidget {
  const SecondSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final leftAndRight = _Container(
      border: BoxBorder.fromSTEB(
          top: _Container.borderSide, bottom: _Container.borderSide),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: _Text(text: 'листать\nвперед\n\ntap'),
          ),
          RotatedBox(
              quarterTurns: 2, child: SvgPicture.asset(SvgAsset.arrowShort)),
        ],
      ),
    );
    final top = _Container(
        border: BoxBorder.fromSTEB(
            start: _Container.borderSide,
            end: _Container.borderSide,
            top: _Container.borderSide),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotatedBox(
                quarterTurns: 2,
                child: SvgPicture.asset(SvgAsset.arrowExtraShort)),
            const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: _Text(text: 'tap\n\nлистать\nназад')),
          ],
        ));
    const bottom = _Container(
      child: _Text(text: 'tap\n\nполный\nэкран'),
    );
    final bottomTap = _Container(
      border: BoxBorder.fromSTEB(bottom: _Container.borderSide),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: _Text(text: 'tap'),
          ),
          SvgPicture.asset(SvgAsset.arrowExtraShort)
        ],
      ),
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
          Positioned(
            left: 100,
            right: 100,
            bottom: bottomPadding,
            top: 3 * cc.maxHeight / 4,
            child: bottomTap,
          ),
        ],
      );
    });
  }
}

class ThirdSlide extends StatelessWidget {
  const ThirdSlide({super.key});

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
