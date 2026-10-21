import 'dart:math' as math;
import 'dart:typed_data';

/// Remove only a uniform background connected to the image perimeter.
/// RGB values, interior highlights and facial detail are never rewritten.
Uint8List mattePortraitRgba(Map<String, Object> input) {
  final source = input['pixels'] as Uint8List;
  final width = input['width'] as int;
  final height = input['height'] as int;
  final output = Uint8List.fromList(source);
  if (width < 4 || height < 4) return output;
  final count = width * height;
  final buckets = <int, List<int>>{};
  void sample(int x, int y) {
    final p = (y * width + x) * 4;
    if (source[p + 3] < 250) return;
    final r = source[p], g = source[p + 1], b = source[p + 2];
    final key = (r ~/ 24) * 121 + (g ~/ 24) * 11 + b ~/ 24;
    final bucket = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
    bucket[0]++;
    bucket[1] += r; bucket[2] += g; bucket[3] += b;
  }
  // The top and upper side borders normally contain the photographic backdrop.
  // Exclude the lower border, where a person's clothes and hands often touch.
  final step = math.max(1, width ~/ 80);
  for (var x = 0; x < width; x += step) sample(x, 0);
  for (var y = 0; y < height ~/ 2; y += step) {
    sample(0, y); sample(width - 1, y);
  }
  final ranked = buckets.values.toList()
    ..sort((a, b) => b[0].compareTo(a[0]));
  if (ranked.isEmpty) return output;
  final dominant = ranked.first;
  final samples = ranked.fold<int>(0, (n, b) => n + b[0]);
  // Complex backgrounds are kept intact instead of guessing away the face.
  if (dominant[0] < samples * .24) return output;
  final red = dominant[1] / dominant[0];
  final green = dominant[2] / dominant[0];
  final blue = dominant[3] / dominant[0];
  final visited = Uint8List(count);
  final background = Uint8List(count);
  final queue = Int32List(count);
  var head = 0, tail = 0;
  bool isBackdrop(int index) {
    final p = index * 4;
    final dr = source[p] - red;
    final dg = source[p + 1] - green;
    final db = source[p + 2] - blue;
    return dr * dr + dg * dg + db * db < 28 * 28;
  }
  void enqueue(int index) {
    if (visited[index] != 0) return;
    visited[index] = 1;
    if (source[index * 4 + 3] < 12 || isBackdrop(index)) {
      background[index] = 1;
      queue[tail++] = index;
    }
  }
  for (var x = 0; x < width; x++) {
    enqueue(x); enqueue((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    enqueue(y * width); enqueue(y * width + width - 1);
  }
  while (head < tail) {
    final index = queue[head++];
    final x = index % width, y = index ~/ width;
    if (x > 0) enqueue(index - 1);
    if (x + 1 < width) enqueue(index + 1);
    if (y > 0) enqueue(index - width);
    if (y + 1 < height) enqueue(index + width);
  }
  // Feather only the actual cut boundary by a source pixel; never use
  // luminance as alpha over the entire image.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      if (background[index] == 0) continue;
      var subjectNeighbours = 0, neighbours = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          neighbours++;
          if (background[ny * width + nx] == 0) subjectNeighbours++;
        }
      }
      final p = index * 4;
      final oldAlpha = source[p + 3];
      final newAlpha = (oldAlpha * subjectNeighbours / neighbours * .45).round();
      output[p + 3] = newAlpha;
      // ui.PixelFormat.rgba8888 uses premultiplied alpha. Keep its colour
      // channels valid at the new matte edge, avoiding pale/black fringes.
      if (oldAlpha > 0) {
        for (var channel = 0; channel < 3; channel++) {
          output[p + channel] = (source[p + channel] * newAlpha / oldAlpha).round();
        }
      }
    }
  }
  return output;
}
