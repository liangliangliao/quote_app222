import 'dart:convert';

/// Only the displayed copy is filtered. Stored diagnostic records stay intact.
String aiLogDisplayDetail(String detail) {
  final marker = detail.indexOf('Body:\n');
  if (marker < 0) return detail;
  final head = detail.substring(0, marker + 6);
  try {
    dynamic clean(dynamic value) {
      if (value is List) return value.map(clean).toList();
      if (value is Map)
        return {
          for (final e in value.entries)
            if (!const {
              'usage',
              'budget',
              'token_usage',
              'max_tokens',
              'max_output_tokens',
              'max_completion_tokens',
              'maxOutputTokens',
              'prompt_tokens',
              'completion_tokens',
              'input_tokens',
              'output_tokens',
              'total_tokens',
              'reasoning_tokens'
            }.contains(e.key))
              e.key: clean(e.value)
        };
      return value;
    }

    return '$head${const JsonEncoder.withIndent('  ').convert(clean(jsonDecode(detail.substring(marker + 6))))}';
  } catch (_) {
    return detail;
  }
}
