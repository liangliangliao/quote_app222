
import 'package:flutter/material.dart';

/// A reusable "wood frame card" which paints the wood image as the component itself,
/// then lays out the [child] on top with configurable inner paddings.
class WoodFrameCard extends StatelessWidget {
  final Widget child;
  final String frameAsset;
  final double frameRadius;
  final double innerRadius;
  final EdgeInsetsGeometry framePadding;   // padding between wood frame and inner white canvas
  final EdgeInsetsGeometry contentPadding; // padding inside the white canvas
  final bool scrollable;                   // whether to wrap [child] with a scroll view
  final bool hideScrollIndicator;
  final List<BoxShadow> shadows;

  const WoodFrameCard({
    super.key,
    required this.child,
    this.frameAsset = 'assets/bg-wood-upload.jpg',
    this.frameRadius = 12.0,
    this.innerRadius = 6.0,
    required this.framePadding,
    this.contentPadding = EdgeInsets.zero,
    this.scrollable = false,
    this.hideScrollIndicator = true,
    this.shadows = const [BoxShadow(color: Colors.black12, blurRadius: 18, spreadRadius: 2, offset: Offset(0,8))],
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
      padding: contentPadding,
      child: child,
    );

    if (scrollable) {
      final scrollableBody = SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: body,
      );
      body = hideScrollIndicator
          ? ScrollConfiguration(
              behavior: _NoIndicatorScroll(),
              child: scrollableBody,
            )
          : scrollableBody;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(frameRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Wood image as the component itself
          Image.asset(frameAsset, fit: BoxFit.cover),
          // Space between wood frame and white canvas
          Padding(
            padding: framePadding,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              clipBehavior: Clip.hardEdge, // never overflow
              child: Container(
                color: Colors.transparent,
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoIndicatorScroll extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}