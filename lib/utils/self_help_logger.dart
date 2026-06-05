import 'dart:convert';

import '../data/db.dart';
import 'debug_logger.dart';

/// Minimal persistent logger for the "Change · Self-help" module.
///
/// Why: on some devices (esp. Android 14), camera PPG may fail due to
/// hardware/driver differences. Persisting a compact diagnostic summary helps
/// reproduce and fix issues without spamming console logs.
class SelfHelpLogger {
  static String _fmtExtra(Map<String, dynamic> extra) {
    try {
      if (extra.isEmpty) return '';
      // Keep ordering stable for easier diff/reading.
      final keys = extra.keys.toList()..sort();
      final parts = <String>[];
      for (final k in keys) {
        final v = extra[k];
        if (v == null) continue;
        String s;
        if (v is double) {
          s = v.toStringAsFixed(3);
        } else {
          s = v.toString();
        }
        // Avoid extremely long lines.
        if (s.length > 120) s = s.substring(0, 120) + '…';
        parts.add('$k=$s');
        if (parts.length >= 14) break; // keep it compact
      }
      if (parts.isEmpty) return '';
      final joined = parts.join(', ');
      return ' {' + joined + (parts.length < extra.length ? ', …' : '') + '}';
    } catch (_) {
      try {
        return ' {json=' + jsonEncode(extra).substring(0, 220) + '…}';
      } catch (_) {
        return '';
      }
    }
  }

  static Future<void> log(
    String level,
    String module,
    String message, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      final db = await AppDatabase.instance();
      await db.insert('self_help_logs', {
        'ts_ms': DateTime.now().millisecondsSinceEpoch,
        'level': level,
        'module': module,
        'message': message,
        'extra_json': extra == null ? null : jsonEncode(extra),
      });
    } catch (_) {
      // Never crash app due to logging.
    }

    // Also mirror key diagnostics into the app-wide `logs` table so that
    // users can view them on the existing Logs page.
    try {
      final tag = 'SH/$module';
      final msg = message + (extra == null ? '' : _fmtExtra(extra));
      final upper = level.toUpperCase();
      if (upper.contains('ERROR') || upper == 'E') {
        await DLog.e(tag, msg);
      } else if (upper.contains('WARN') || upper == 'W') {
        await DLog.w(tag, msg);
      } else {
        await DLog.i(tag, msg);
      }
    } catch (_) {
      // ignore
    }
  }

  static Future<List<Map<String, dynamic>>> latest({int limit = 100}) async {
    try {
      final db = await AppDatabase.instance();
      return await db.query(
        'self_help_logs',
        orderBy: 'ts_ms DESC, id DESC',
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }
}
