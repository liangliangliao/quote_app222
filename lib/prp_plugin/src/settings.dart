import 'dart:convert';

import 'models.dart';

class PrpPreferences {
  const PrpPreferences({
    this.enabled = false,
    this.surfaces = const {
      PrpSurface.enemy: true,
      PrpSurface.behavior: true,
      PrpSurface.failureModule: true,
      PrpSurface.kindling: false,
      PrpSurface.quoteHome: false,
    },
    this.pauseSeconds = 60,
    this.offerCap = 1,
    this.recallCap = 1,
    this.aiConsent = false,
    this.onboarded = false,
    this.sessions = true,
    this.recalls = true,
    this.quoteStream = false,
    this.manuscript = true,
    this.voice = false,
  });
  final bool enabled;
  final Map<PrpSurface, bool> surfaces;
  final int pauseSeconds;
  final int offerCap;
  final int recallCap;
  final bool aiConsent;
  final bool onboarded;
  final bool sessions;
  final bool recalls;
  final bool quoteStream;
  final bool manuscript;
  final bool voice;

  PrpPreferences copyWith({
    bool? enabled,
    Map<PrpSurface, bool>? surfaces,
    int? pauseSeconds,
    int? offerCap,
    int? recallCap,
    bool? aiConsent,
    bool? onboarded,
    bool? sessions,
    bool? recalls,
    bool? quoteStream,
    bool? manuscript,
    bool? voice,
  }) =>
      PrpPreferences(
        enabled: enabled ?? this.enabled,
        surfaces: Map.unmodifiable(surfaces ?? this.surfaces),
        pauseSeconds: (pauseSeconds ?? this.pauseSeconds).clamp(30, 180),
        offerCap: (offerCap ?? this.offerCap).clamp(0, 3),
        recallCap: (recallCap ?? this.recallCap).clamp(0, 3),
        aiConsent: aiConsent ?? this.aiConsent,
        onboarded: onboarded ?? this.onboarded,
        sessions: sessions ?? this.sessions,
        recalls: recalls ?? this.recalls,
        quoteStream: quoteStream ?? this.quoteStream,
        manuscript: manuscript ?? this.manuscript,
        voice: voice ?? this.voice,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'surfaces': {
          for (final s in PrpSurface.values) s.key: surfaces[s] == true
        },
        'pause_sec': pauseSeconds,
        'offer_cap': offerCap,
        'recall_cap': recallCap,
        'ai_consent': aiConsent,
        'onboarded': onboarded,
        'sessions': sessions,
        'recalls': recalls,
        'quote_stream': quoteStream,
        'manuscript': manuscript,
        'voice': voice,
      };

  static PrpPreferences fromJson(Map<String, dynamic> m) {
    const defaults = PrpPreferences();
    final raw = m['surfaces'];
    return defaults.copyWith(
      enabled: m['enabled'] == true,
      surfaces: {
        for (final s in PrpSurface.values)
          s: raw is Map && raw[s.key] is bool
              ? raw[s.key] as bool
              : defaults.surfaces[s]!
      },
      pauseSeconds: (m['pause_sec'] as num?)?.toInt(),
      offerCap: (m['offer_cap'] as num?)?.toInt(),
      recallCap: (m['recall_cap'] as num?)?.toInt(),
      aiConsent: m['ai_consent'] == true,
      onboarded: m['onboarded'] == true,
      sessions: m['sessions'] != false,
      recalls: m['recalls'] != false,
      quoteStream: m['quote_stream'] == true,
      manuscript: m['manuscript'] != false,
      voice: m['voice'] == true,
    );
  }
}

typedef PrpReadSetting = Future<String?> Function(String key);
typedef PrpWriteSetting = Future<void> Function(String key, String value);

/// One atomic KV value avoids partially saved switch combinations on restart.
class PrpSettings {
  const PrpSettings({required this.read, required this.write});
  static const key = 'prp.preferences.v1';
  final PrpReadSetting read;
  final PrpWriteSetting write;
  Future<PrpPreferences> load() async {
    final raw = await read(key);
    if (raw == null || raw.isEmpty) return const PrpPreferences();
    return PrpPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(PrpPreferences p) => write(key, jsonEncode(p.toJson()));
}
