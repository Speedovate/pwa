import 'package:flutter/material.dart';

class PageIndicatorWidget extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double spacing;
  final double activeSize;
  final double inactiveSize;
  final Color activeColor;
  final Color inactiveColor;

  const PageIndicatorWidget({
    this.count = 1,
    this.currentIndex = 0,
    this.spacing = 2.5,
    this.activeSize = 8,
    this.inactiveSize = 6,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: spacing),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: currentIndex == index ? activeSize : inactiveSize,
              height: currentIndex == index ? activeSize : inactiveSize,
              decoration: BoxDecoration(
                color: currentIndex == index ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(6.0),
              ),
            ),
          );
        },
      ),
    );
  }
}
