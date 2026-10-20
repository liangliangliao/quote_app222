import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_portrait_matte.dart';

void main() {
  Uint8List fixture(int background, int outline, int face) {
    final bytes = Uint8List(40 * 50 * 4);
    for (var y = 0; y < 50; y++) {
      for (var x = 0; x < 40; x++) {
        var value = background;
        if (x >= 10 && x < 30 && y >= 8 && y < 48) value = outline;
        if (x >= 14 && x < 26 && y >= 14 && y < 30) value = face;
        final p = (y * 40 + x) * 4;
        bytes[p] = value; bytes[p + 1] = value; bytes[p + 2] = value;
        bytes[p + 3] = 255;
      }
    }
    return bytes;
  }
  for (final dark in [false, true]) {
    test('matte keeps bright face and dark details on ${dark ? "dark" : "light"} background', () {
      final input = fixture(dark ? 50 : 250, dark ? 105 : 70, 245);
      // A dark eye inside the bright face must stay opaque too.
      final eye = (20 * 40 + 20) * 4;
      input[eye] = 12; input[eye + 1] = 12; input[eye + 2] = 12;
      final output = mattePortraitRgba({
        'pixels': input, 'width': 40, 'height': 50,
      });
      expect(output[3], 0);
      final cheek = (22 * 40 + 23) * 4;
      expect(output.sublist(cheek, cheek + 4), [245, 245, 245, 255]);
      expect(output.sublist(eye, eye + 4), [12, 12, 12, 255]);
      expect(input[3], 255, reason: 'The original must not be mutated');
    });
  }
  test('an enclosed background-coloured facial detail remains opaque', () {
    final input = fixture(250, 70, 250);
    final result = mattePortraitRgba({
      'pixels': input, 'width': 40, 'height': 50,
    });
    expect(result[(20 * 40 + 20) * 4 + 3], 255);
  });
}
