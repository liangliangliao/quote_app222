import 'dart:convert';

import 'package:http/http.dart' as http;

/// Independent wire-schema check from https://docs.typesafe.ai/api.
/// Test doubles must reject the same malformed Score/Choice criteria as JEV.
void validateJevWireRequest(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  if (body['state'] == null ||
      body['model'] is! String ||
      body['questions'] is! Map ||
      (body['questions'] as Map).isEmpty) {
    throw const FormatException('Missing required JEV request fields');
  }
  for (final entry in (body['questions'] as Map).entries) {
    final q = entry.value as Map;
    final criteria = q['criteria'];
    switch (q['type']) {
      case 'score':
        if (criteria is! List || criteria.length < 2 || criteria.length > 10) {
          throw FormatException(
              'questions.${entry.key}.criteria must be an ordered array');
        }
      case 'choice':
        if (criteria is! Map || criteria.isEmpty || criteria.length > 255) {
          throw FormatException(
              'questions.${entry.key}.criteria must be an option map');
        }
      case 'noul':
        if (criteria != null && criteria is! Map) {
          throw FormatException(
              'questions.${entry.key}.criteria must be an object');
        }
      default:
        throw FormatException('Unsupported question type: ${q['type']}');
    }
  }
}

http.Response validJevWireReply(http.Request request) {
  validateJevWireRequest(request);
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  final answers = <String, dynamic>{};
  for (final entry in (body['questions'] as Map).entries) {
    final q = entry.value as Map;
    if (q['type'] == 'score') {
      final levels = q['criteria'] as List;
      answers[entry.key as String] = {
        'type': 'score',
        'score': (levels.length - 1) * .8,
        'confidence': .8,
        'legend': {for (var i = 0; i < levels.length; i++) '$i': levels[i]}
      };
    } else if (q['type'] == 'noul') {
      answers[entry.key as String] = {
        'type': 'noul',
        'noul': entry.key == 'hard_blocker' ? .01 : .85
      };
    } else {
      final criteria = q['criteria'] as Map;
      final choice = ['protective', 'supportive', 'no_major_theory_blocker']
              .where(criteria.containsKey)
              .firstOrNull ??
          criteria.keys.first;
      answers[entry.key as String] = {
        'type': 'choice',
        'choice': choice,
        'confidence': .8
      };
    }
  }
  return http.Response(
      jsonEncode({'model': 'jev-wire-fixture', 'answers': answers}), 200);
}
