import 'package:flutter/material.dart';

/// 朱红印章色。
const Color kPrpSeal = Color(0xFFB23A3A);

/// 一枚小印章。[active] 为 false 时是淡淡的底印（还没盖）。
class PrpSealStamp extends StatelessWidget {
  const PrpSealStamp({
    super.key,
    this.size = 56,
    this.active = true,
    this.text = '印',
  });

  final double size;
  final bool active;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1.0 : 0.25,
      child: Transform.rotate(
        angle: -0.12,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: kPrpSeal, width: 2.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: kPrpSeal,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}
