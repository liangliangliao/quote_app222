import 'package:flutter/material.dart';

const journeyInk = Color(0xff173e32);
const journeyGreen = Color(0xff426d58);
const journeyMuted = Color(0xff7e8a80);
const journeyPaper = Color(0xfff7f8f3);

enum JourneyArt { mountains, book, stones, path, sprout, doorway }

/// The six illustrations share a single local image. Clipping selects a cell
/// without fetching remote art or changing the card when its data refreshes.
class JourneyIllustration extends StatelessWidget {
  const JourneyIllustration(this.art, {super.key, this.opacity = 1});
  final JourneyArt art;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: LayoutBuilder(
          builder: (context, bounds) => ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -(art.index % 3) * bounds.maxWidth,
                  top: -(art.index ~/ 3) * bounds.maxHeight,
                  width: bounds.maxWidth * 3,
                  height: bounds.maxHeight * 2,
                  child: Image.asset(
                    'assets/journey/vignettes.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class JourneyHeaderBackdrop extends StatelessWidget {
  const JourneyHeaderBackdrop({
    super.key,
    this.discovery = false,
    this.flip = false,
    this.opacity = 1,
  });
  final bool discovery;
  final bool flip;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: opacity,
            child: Transform.flip(
              flipX: flip,
              child: Image.asset(
                discovery
                    ? 'assets/journey/discovery_header.png'
                    : 'assets/journey/rhythm_header.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22f7f8f3), Color(0x00f7f8f3), journeyPaper],
                stops: [0, .65, 1],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class JourneySurface extends StatelessWidget {
  const JourneySurface({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.white,
    this.radius = 17,
  });
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0657684d),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: Color(0xdfffffff)),
      ),
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class JourneyIcon extends StatelessWidget {
  const JourneyIcon(this.icon, {super.key, this.size = 44});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .29),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffeff4ed), Color(0xffe7eee5)],
      ),
    ),
    child: Icon(icon, color: journeyGreen, size: size * .56),
  );
}

class JourneyFilterChip extends StatelessWidget {
  const JourneyFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
    this.dense = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: selected
              ? const [Color(0xff8ba47b), Color(0xff3d7057)]
              : const [Color(0xdfffffff), Color(0x99ffffff)],
        ),
        border: Border.all(color: const Color(0xdfffffff)),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x15566e47),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 4 : (icon == null ? 17 : 12),
              vertical: compact
                  ? 5
                  : dense
                  ? 8
                  : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: dense ? 13 : 16,
                    color: selected ? Colors.white : const Color(0xff819185),
                  ),
                  SizedBox(width: dense ? 3 : 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: dense ? 10.5 : 12,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.white : const Color(0xff788179),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class JourneyAiOrb extends StatelessWidget {
  const JourneyAiOrb({super.key, this.size = 58});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xffd7e9ff), width: 2),
      gradient: const RadialGradient(
        center: Alignment(-.45, -.55),
        radius: 1.2,
        colors: [
          Color(0xff49d6ed),
          Color(0xff5878ff),
          Color(0xff8b46ee),
          Color(0xffc4a2ff),
        ],
        stops: [0, .35, .7, 1],
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x446e8cfd), blurRadius: 17, spreadRadius: 3),
        BoxShadow(color: Color(0x99ffffff), blurRadius: 3, spreadRadius: 3),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size * .53),
        Positioned(
          right: size * .1,
          bottom: size * .12,
          child: Container(
            width: size * .15,
            height: size * .15,
            decoration: BoxDecoration(
              color: const Color(0xff54d499),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.7),
            ),
          ),
        ),
      ],
    ),
  );
}
