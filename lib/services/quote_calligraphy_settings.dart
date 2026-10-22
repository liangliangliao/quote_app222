import 'package:flutter/foundation.dart';

import '../data/kv_dao.dart';

/// The three brush-writing faces available for the home quote body.
enum QuoteCalligraphyStyle {
  xingshu,
  kaishu,
  caoshu;

  static QuoteCalligraphyStyle parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'kaishu':
        return QuoteCalligraphyStyle.kaishu;
      case 'caoshu':
        return QuoteCalligraphyStyle.caoshu;
      default:
        return QuoteCalligraphyStyle.xingshu;
    }
  }

  String get storageValue => name;

  String get label => switch (this) {
        QuoteCalligraphyStyle.xingshu => '行书',
        QuoteCalligraphyStyle.kaishu => '楷书',
        QuoteCalligraphyStyle.caoshu => '草书',
      };

  String get description => switch (this) {
        QuoteCalligraphyStyle.xingshu => '流动自然',
        QuoteCalligraphyStyle.kaishu => '端正典雅',
        QuoteCalligraphyStyle.caoshu => '奔放写意',
      };

  String get fontFamily => switch (this) {
        QuoteCalligraphyStyle.xingshu => 'QuoteXingShu',
        QuoteCalligraphyStyle.kaishu => 'QuoteKaiShu',
        QuoteCalligraphyStyle.caoshu => 'QuoteCaoShu',
      };
}

@immutable
class QuoteCalligraphyPreferences {
  const QuoteCalligraphyPreferences({
    this.animationEnabled = false,
    this.style = QuoteCalligraphyStyle.xingshu,
  });

  final bool animationEnabled;
  final QuoteCalligraphyStyle style;
}

/// Persists the optional home calligraphy presentation.
///
/// The missing-value contract deliberately resolves to `false`, so an upgrade
/// cannot unexpectedly replace the existing static quote presentation.
class QuoteCalligraphySettings {
  QuoteCalligraphySettings({KeyValueDao? dao}) : _dao = dao ?? KeyValueDao();

  static const animationEnabledKey =
      'quote_calligraphy_animation_enabled_v1';
  static const styleKey = 'quote_calligraphy_style_v1';

  static final ValueNotifier<int> changeTick = ValueNotifier<int>(0);

  final KeyValueDao _dao;

  Future<QuoteCalligraphyPreferences> load() async {
    final enabled =
        (await _dao.getString(animationEnabledKey))?.trim().toLowerCase() ==
            'true';
    final style = QuoteCalligraphyStyle.parse(await _dao.getString(styleKey));
    return QuoteCalligraphyPreferences(
      animationEnabled: enabled,
      style: style,
    );
  }

  Future<void> setAnimationEnabled(bool enabled) async {
    await _dao.setString(animationEnabledKey, enabled.toString());
    changeTick.value += 1;
  }

  Future<void> setStyle(QuoteCalligraphyStyle style) async {
    await _dao.setString(styleKey, style.storageValue);
    changeTick.value += 1;
  }
}
