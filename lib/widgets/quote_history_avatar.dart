import 'package:flutter/material.dart';

/// A circular history portrait with a head-safe crop.
///
/// `CircleAvatar.backgroundImage` always crops around the image centre, which
/// can remove the forehead and hair from tall portraits. Keeping the crop at
/// the top preserves the complete head while allowing the lower torso to be
/// trimmed naturally.
class QuoteHistoryAvatar extends StatelessWidget {
  const QuoteHistoryAvatar({
    super.key,
    required this.image,
    required this.diameter,
  });

  final ImageProvider? image;
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xfff1ece6),
            border: Border.all(color: const Color(0xffded3c8), width: .8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(.8),
            child: ClipOval(
              child: image == null
                  ? Icon(
                      Icons.format_quote_rounded,
                      size: diameter * .46,
                      color: const Color(0xff74675d),
                    )
                  : Image(
                      image: image!,
                      width: diameter,
                      height: diameter,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.format_quote_rounded,
                        size: diameter * .46,
                        color: const Color(0xff74675d),
                      ),
                    ),
            ),
          ),
        ),
      );
}
