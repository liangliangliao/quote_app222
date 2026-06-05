import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

import '../data/dao.dart';
import '../utils/debug_logger.dart';

/// 简化且可编译的 POI 模型（页面仅读取这些字段）。

// ---- Coordinate conversion helpers (minimal, for distance comparison only) ----
// Reference formulas widely used for China coordinate conversions.
// We keep them small and self-contained to avoid extra dependencies.
const _pi = 3.1415926535897932384626;
const _a = 6378245.0; // Krasovsky ellipsoid
const _ee = 0.00669342162296594323;

bool _outOfChina(double lat, double lon) {
  return lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

double _transformLat(double x, double y) {
  var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * (x.abs().sqrt());
  ret += (20.0 * (6.0 * x * _pi)).sin() * 20.0 / 3.0;
  ret += (20.0 * (2.0 * x * _pi)).sin() * 20.0 / 3.0;
  ret += (20.0 * (y * _pi)).sin() * 40.0 / 3.0;
  ret += (20.0 * (y / 3.0 * _pi)).sin() * 40.0 / 3.0;
  ret += (160.0 * (y / 12.0 * _pi)).sin() * 20.0 / 3.0;
  ret += (320.0 * (y * _pi / 30.0)).sin() * 20.0 / 3.0;
  return ret;
}

double _transformLon(double x, double y) {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * (x.abs().sqrt());
  ret += (20.0 * (6.0 * x * _pi)).sin() * 20.0 / 3.0;
  ret += (20.0 * (2.0 * x * _pi)).sin() * 20.0 / 3.0;
  ret += (20.0 * (x * _pi)).sin() * 40.0 / 3.0;
  ret += (20.0 * (x / 3.0 * _pi)).sin() * 40.0 / 3.0;
  ret += (150.0 * (x / 12.0 * _pi)).sin() * 20.0 / 3.0;
  ret += (300.0 * (x / 30.0 * _pi)).sin() * 20.0 / 3.0;
  return ret;
}

List<double> _gcj02ToWgs84(double lat, double lon) {
  if (_outOfChina(lat, lon)) return [lat, lon];
  var dLat = _transformLat(lon - 105.0, lat - 35.0);
  var dLon = _transformLon(lon - 105.0, lat - 35.0);
  var radLat = lat / 180.0 * _pi;
  var magic = (radLat.sin());
  magic = 1 - _ee * magic * magic;
  var sqrtMagic = magic.sqrt();
  dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * _pi);
  dLon = (dLon * 180.0) / (_a / sqrtMagic * (radLat.cos()) * _pi);
  var mgLat = lat + dLat;
  var mgLon = lon + dLon;
  return [lat * 1.0 * 2 - mgLat, lon * 1.0 * 2 - mgLon];
}

List<double> _bd09ToGcj02(double lat, double lon) {
  var x = lon - 0.0065;
  var y = lat - 0.006;
  var z = (x * x + y * y).sqrt() - 0.00002 * (y * _pi).sin();
  var theta = (y).atan2(x) - 0.000003 * (x * _pi).cos();
  var ggLon = z * theta.cos();
  var ggLat = z * theta.sin();
  return [ggLat, ggLon];
}

List<double> _bd09ToWgs84(double lat, double lon) {
  final g = _bd09ToGcj02(lat, lon);
  return _gcj02ToWgs84(g[0], g[1]);
}

// small numeric helpers
extension _NumOps on num {
  double sqrt() => math.sqrt(this.toDouble());
  double sin() => math.sin(this.toDouble());
  double cos() => math.cos(this.toDouble());
  double atan2(num x) => math.atan2(this.toDouble(), x.toDouble());
}
class PoiItem {
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int? distance;
  PoiItem({
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
  });
}

class LocationService {
  // 仅按“名称唯一”去重：相同名称仅保留第一条（通常是距离更近的，因为上游已按 distance 排序）
  static List<PoiItem> _dedupByNameStrict(List<PoiItem> src) {
    if (src.length <= 1) return src;
    final out = <PoiItem>[];
    final seen = <String>{};
    String norm(String? s) {
      final v = (s ?? '')
          .replaceAll('\u200B', '')
          .replaceAll('\uFEFF', '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return v;
    }
    for (final p in src) {
      final key = norm(p.name);
      if (key.isEmpty) { out.add(p); continue; }
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(p);
    }
    return out;
  }

  static const MethodChannel _sysCh = MethodChannel('com.example.quote_app/sys');

  // 若百度 AK 鉴权失败（locType=505/506），短时间内跳过百度SDK逆地理，避免反复报错刷屏。
  static DateTime? _baiduAuthBrokenUntil;

  /// 获取位置时希望的最大精度（半径）阈值，单位：米。
  /// 当精度大于此阈值时，将视为不满足高精度要求而继续回退到下一方案。
  static const bool _compareBaiduWithSystem = false; // 不再比较，按你的要求
static const double _desiredAccuracyMeters = 40.0;

  /// 最近一次成功定位所采用的提供者名称（baidu 或 system）。
  /// 如果定位失败或尚未调用，则为 null。
  static String? lastProvider;

  /// 最近一次百度 SDK 定位回传的 locType（用于判断是否为 GPS/网络/缓存等）。
  /// 常见：61=GPS，161=网络，66=离线（不可靠）。
  static int? lastBaiduLocType;
  static String? lastBaiduLocTime;
  static String? lastBaiduNetType;

  /// 系统定位优先 -> 失败回退百度SDK。
  ///
  /// 该策略用于“新增地点规则/更新目标位置”等手动流程：尽量拿到系统高精度坐标，
  /// 若系统定位失败或精度不满足阈值，再尝试百度SDK。
  static Future<Position?> getCurrentPositionPreferSystem() async {
    // 1. 系统优先
    try {
      final sys = await _getCurrentPositionHighAccuracy();
      if (sys != null) {
        if (sys.accuracy <= _desiredAccuracyMeters) {
          lastProvider = 'system';
          try {
            await DLog.i(
              'LocationService',
              '【定位】系统定位成功 acc=${sys.accuracy}m, lat=${sys.latitude}, lon=${sys.longitude}',
            );
          } catch (_) {}
          unawaited(_logNearbyLandmarkIfPossible(sys));
          return sys;
        } else {
          try {
            await DLog.w(
              'LocationService',
              '【定位】系统定位精度不满足要求 acc=${sys.accuracy}m (>$_desiredAccuracyMeters m)，尝试 Baidu SDK',
            );
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2. Baidu 兜底
    try {
      final bd = await _baiduSdkLocationWithRetry(2);
      if (bd != null) {
        if (bd.accuracy <= _desiredAccuracyMeters) {
          lastProvider = 'baidu';
          try {
            await DLog.i(
              'LocationService',
              '【定位】Baidu SDK 成功 acc=${bd.accuracy}m, lat=${bd.latitude}, lon=${bd.longitude}',
            );
          } catch (_) {}
          unawaited(_logNearbyLandmarkIfPossible(bd));
          return bd;
        } else {
          try {
            await DLog.w(
              'LocationService',
              '【定位】Baidu SDK 精度不满足要求 acc=${bd.accuracy}m (>$_desiredAccuracyMeters m)',
            );
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. lastKnown 兜底
    try {
      final last = await _getLastKnownPosition();
      if (last != null) {
        lastProvider = 'last_known';
        return last;
      }
    } catch (_) {}

    lastProvider = null;
    try {
      await DLog.w(
        'LocationService',
        '【定位】系统 / Baidu / lastKnown 全部失败，无法获取位置',
      );
    } catch (_) {}
    return null;
  }

  /// 百度SDK优先 -> 失败回退系统定位（高精度）。
  ///
  /// - 默认行为保持兼容：若 Baidu 精度不达标，会回退系统定位与 lastKnown。
  /// - 当 [allowFallback] 为 false 时：仅尝试 Baidu（按 [baiduMaxAttempts] 重试），
  ///   且必须满足 acc <= 31m，否则直接返回 null（用于“目标位置定位”严格精度场景）。
  static Future<Position?> getCurrentPositionPreferBaidu({
    bool allowFallback = true,
    int baiduMaxAttempts = 2,
  }) async {
    final bool strictAcc = !allowFallback;
    // 1. Baidu SDK 优先
    try {
      final bd = await _baiduSdkLocationWithRetry(
        baiduMaxAttempts <= 0 ? 1 : baiduMaxAttempts,
        strict: strictAcc,
      );
      if (bd != null) {
        if (bd.accuracy <= _desiredAccuracyMeters) {
          lastProvider = 'baidu';
          try {
            await DLog.i(
              'LocationService',
              '【定位】Baidu SDK 成功 acc=${bd.accuracy.toStringAsFixed(3)}m, lat=${bd.latitude}, lon=${bd.longitude}',
            );
          } catch (_) {}
          unawaited(_logNearbyLandmarkIfPossible(bd));
          return bd;
        } else {
          try {
            await DLog.w(
              'LocationService',
              '【定位】Baidu SDK 精度不满足要求 acc=${bd.accuracy.toStringAsFixed(3)}m (>=${_desiredAccuracyMeters.toStringAsFixed(1)}m)${allowFallback ? '，尝试系统定位' : '，严格模式下尝试系统高精度流兜底'}',
            );
          } catch (_) {}
        }
      } else {
        // strict 模式下也继续尝试系统高精度流兜底（但不走 lastKnown）。
      }
    } catch (_) {
      // 已在 _baiduSdkLocationOnce 内部记录日志，这里忽略异常。
      // strict 模式下也继续尝试系统高精度流兜底（但不走 lastKnown）。
    }

    // 2. 系统高精度定位
    try {
      final sys = await _getCurrentPositionHighAccuracy();
      if (sys != null) {
        if (sys.accuracy <= _desiredAccuracyMeters) {
          lastProvider = 'system';
          try {
            await DLog.i(
              'LocationService',
              '【定位】系统定位成功 acc=${sys.accuracy.toStringAsFixed(3)}m, lat=${sys.latitude}, lon=${sys.longitude}',
            );
          } catch (_) {}
          unawaited(_logNearbyLandmarkIfPossible(sys));
          return sys;
        } else {
          try {
            await DLog.w(
              'LocationService',
              '【定位】系统定位精度不满足要求 acc=${sys.accuracy.toStringAsFixed(3)}m (>=${_desiredAccuracyMeters.toStringAsFixed(1)}m)',
            );
          } catch (_) {}
        }
      }
    } catch (_) {
      // 已在 _getCurrentPositionHighAccuracy 内部记录日志。
    }

    // strict 模式：不允许 lastKnown（容易取到粗定位/历史位置）。
    if (!strictAcc) {
      // 3. lastKnown 兜底
      try {
        final last = await _getLastKnownPosition();
        if (last != null) {
          lastProvider = 'last_known';
          return last;
        }
      } catch (_) {}
    }

    lastProvider = null;
    try {
      await DLog.w(
        'LocationService',
        strictAcc
            ? '【定位】Baidu / System 均未达到精度要求（strict），无法获取位置'
            : '【定位】Baidu / System / lastKnown 全部失败，无法获取位置',
      );
    } catch (_) {}
    return null;
  }

  /// 获取“当前尽可能正确”的位置：百度SDK优先、系统定位兜底。
  ///
  /// 适用场景：规则地点提醒/目标位置获取。
  /// 目标是：能拿到真实当前位置就拿真实；拿不到时也不要直接失败，而是返回
  /// **离设备最近的可用结果**（本质上是：在所有实时候选结果中选择
  /// `accuracy` 最小且时间最新的那个）。
  ///
  /// 说明：任何 SDK 都无法在所有环境下 100% 保证 <31m（尤其室内）。
  /// 因此这里会：
  /// 1) 优先等待达标(<=31m)；
  /// 2) 达标不了则返回 best-effort（但会在日志里提示精度一般）。
  ///
  /// [useLastKnown] 默认 false：避免把历史粗定位当“当前位置”。
  static Future<Position?> getBestCurrentPositionPreferBaidu({
    int baiduMaxAttempts = 3,
    bool useLastKnown = false,
  }) async {
    Position? bd;
    Position? sys;

    // 1) Baidu SDK：优先获取（可多次重试，内部会返回最后一次结果）
    try {
      bd = await _baiduSdkLocationWithRetry(
        baiduMaxAttempts <= 0 ? 1 : baiduMaxAttempts,
        strict: false,
      );
    } catch (_) {}

    // 若百度已达标，直接返回（按你的要求：不再与系统结果比较）
    if (bd != null && bd.accuracy <= _desiredAccuracyMeters) {
      lastProvider = 'baidu';
      try {
        await DLog.i(
          'LocationService',
          '【定位】Baidu SDK 成功 acc=${bd.accuracy}m, lat=${bd.latitude}, lon=${bd.longitude}',
        );
      } catch (_) {}
      unawaited(_logNearbyLandmarkIfPossible(bd));
      return bd;
    }

    // 3. lastKnown 兜底
    try {
      final last = await _getLastKnownPosition();
      if (last != null) {
        lastProvider = 'last_known';
        return last;
      }
    } catch (_) {}

    lastProvider = null;
    try {
      await DLog.w(
        'LocationService',
        '【定位】系统 / Baidu / lastKnown 全部失败，无法获取位置',
      );
    } catch (_) {}
    return null;
  }

  /// 百度SDK优先 -> 失败回退系统定位（高精度）。
  ///
  /// - 默认行为保持兼容：若 Baidu 精度不达标，会回退系统定位与 lastKnown。
  /// - 当 [allowFallback] 为 false 时：仅尝试 Baidu（按 [baiduMaxAttempts] 重试），
  ///   且必须满足 acc <= 31m，否则直接返回 null（用于“目标位置定位”严格精度场景）。
  

  // [Removed duplicate method definition during merge]



  /// 获取“当前尽可能正确”的位置：百度SDK优先、系统定位兜底。
  ///
  /// 适用场景：规则地点提醒/目标位置获取。
  /// 目标是：能拿到真实当前位置就拿真实；拿不到时也不要直接失败，而是返回
  /// **离设备最近的可用结果**（本质上是：在所有实时候选结果中选择
  /// `accuracy` 最小且时间最新的那个）。
  ///
  /// 说明：任何 SDK 都无法在所有环境下 100% 保证 <31m（尤其室内）。
  /// 因此这里会：
  /// 1) 优先等待达标(<=31m)；
  /// 2) 达标不了则返回 best-effort（但会在日志里提示精度一般）。
  ///
  /// [useLastKnown] 默认 false：避免把历史粗定位当“当前位置”。
  

  // [Removed duplicate method definition during merge]



  
  
  static Future<Position?> _getCurrentPositionHighAccuracy() async {
    // 先尝试原生系统高精度单次定位（保证新鲜），失败再回退到 geolocator。
    try {
      try { await DLog.i('LocationService', '【定位】系统高精度兜底：开始调用 getSystemLocationOnce'); } catch (_) {}
      // Android 侧系统高精度定位可能需要同时等待 Fused(约12s) + GPS(约10s) 的收敛；
      // 这里适度放宽超时，避免 Future not completed 的假失败。
      final ret = await _sysCh.invokeMethod('getSystemLocationOnce')
          .timeout(const Duration(seconds: 25));
      if (ret is Map) {
        final lat = (ret['lat'] as num?)?.toDouble();
        final lng = (ret['lng'] as num?)?.toDouble();
        final acc = (ret['acc'] as num?)?.toDouble() ?? 0.0;
        if (lat != null && lng != null) {
          return Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: acc,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }
      try { await DLog.w('LocationService', '【定位】系统高精度兜底：返回数据为空/不完整（ret=${ret.runtimeType}）'); } catch (_) {}
    } catch (e) {
      try { await DLog.w('LocationService', '【定位】系统高精度兜底：调用异常：$e'); } catch (_) {}
    }

    // geolocator 兜底
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        try { await DLog.w('LocationService', '【定位】未授予定位权限'); } catch (_) {}
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    } catch (_) {
      return null;
    }
  }
static Future<Position?> _baiduSdkLocationOnce() async {
    try {
      // 每次调用前清理上次百度元信息，避免失败时日志显示旧值。
      lastBaiduLocType = null;
      lastBaiduLocTime = null;
      lastBaiduNetType = null;
      final ret = await _sysCh.invokeMethod('getBaiduLocationOnce');
      if (ret is Map) {
        final lat = (ret['lat'] as num?)?.toDouble();
        final lng = (ret['lng'] as num?)?.toDouble();
        final acc = (ret['acc'] as num?)?.toDouble() ?? 0.0;
        final provider = ret['provider']?.toString();
        // 记录百度侧元信息，用于后续“假精准偏移”判定与日志分析。
        try {
          final lt = ret['locType'];
          if (lt is int) {
            lastBaiduLocType = lt;
          } else if (lt is num) {
            lastBaiduLocType = lt.toInt();
          }
          final t = ret['locTime'];
          if (t is String && t.trim().isNotEmpty) lastBaiduLocTime = t.trim();
          final nt = ret['netType'];
          if (nt is String && nt.trim().isNotEmpty) lastBaiduNetType = nt.trim();

          // 关键调试信息：确保用户在“日志”页能看到百度定位的 locType/时间/网络类型。
          // 注意：这里只做信息级别输出，不影响业务流程。
          try {
            await DLog.i(
              'LocationService',
              '【定位】Baidu SDK 原始元信息 provider=${provider ?? "na"}, locType=${lastBaiduLocType ?? -1}, locTime=${lastBaiduLocTime ?? "na"}, netType=${lastBaiduNetType ?? "na"}',
            );
          } catch (_) {}
        } catch (_) {}
        if (lat != null && lng != null) {
          final pos = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: acc,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          return pos;
        }
      }
    } catch (e) {
      try {
        if (e is PlatformException) {
          await DLog.w(
            'LocationService',
            '【定位】Baidu SDK 调用失败 code=${e.code}, message=${e.message}, details=${e.details}',
          );

          // 特判：locType=505/506 为 AK/服务鉴权类错误，继续重试没有意义，只会刷屏。
          try {
            final d = e.details;
            if (d is Map) {
              final lt = d['locType'];
              if (lt == 505 || lt == 506) {
                _baiduAuthBrokenUntil = DateTime.now().add(const Duration(minutes: 10));
                await DLog.w(
                  'LocationService',
                  '【定位】百度SDK鉴权失败 locType=$lt（505=AK不存在或非法；506=定位服务未开启）。请到百度LBS控制台核对：包名+SHA1(开发版/发布版)是否匹配，并确保勾选了定位服务。',
                );
              }
            }
          } catch (_) {}
        } else {
          await DLog.w('LocationService', '【定位】Baidu SDK 调用失败：$e');
        }
      } catch (_) {}
    }
    return null;
  }

  /// 记录附近地标（百度逆地理），仅写日志，失败不抛出。
  static Future<void> _logNearbyLandmarkIfPossible(Position pos) async {
    try {
      bool skipSdk = false;
      // 若近期已确认百度 AK/服务鉴权失败，则直接跳过百度SDK逆地理，避免重复报错。
      final until = _baiduAuthBrokenUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        await DLog.w('LocationService', '【定位】跳过百度SDK逆地理（近期鉴权失败，直到 $until），改走Web兜底');
        skipSdk = true;
      }
      // 1) 优先用 Baidu Search SDK 逆地理（使用移动端 AK，不依赖 Web 服务 AK/IP 白名单）。
      //    这样系统定位成功后也能稳定得到中文语义描述/附近 POI，并输出中文日志。
      if (!skipSdk) {
        try {
          final coordType = (lastProvider == 'baidu') ? 'bd09ll' : 'wgs84ll';
          final ret = await _sysCh.invokeMethod('reverseGeocodePoisBaiduSdk', {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'radius': 600,
            'coordType': coordType,
          }).timeout(const Duration(seconds: 8));

        if (ret is Map) {
          final pois = ret['pois'];
          if (pois is List && pois.isNotEmpty) {
            final first = pois.first;
            String? name;
            int? distance;
            if (first is Map) {
              final n = first['name'];
              final d = first['distance'];
              if (n is String) name = n;
              if (d is int) distance = d;
              if (d is num) distance = d.toInt();
            }
            if (name != null && name!.trim().isNotEmpty) {
              final suffix = (distance != null) ? '（约${distance}米）' : '';
              try {
                await DLog.i('LocationService', '附近地标（SDK）：${name!.trim()}$suffix');
              } catch (_) {}
              return;
            }
          }
        }
          // SDK 无结果时继续走 Web 兜底。
          try {
            await DLog.w('LocationService', '【定位】SDK逆地理无结果，尝试Web逆地理兜底');
          } catch (_) {}
        } catch (e) {
          // SDK 逆地理失败不影响业务，继续走 Web 兜底。
          try {
            await DLog.w('LocationService', '【定位】SDK逆地理失败，尝试Web逆地理兜底：$e');
            try {
              if (e is PlatformException && e.code == 'baidu_sdk_init_failed') {
                _baiduAuthBrokenUntil = DateTime.now().add(const Duration(minutes: 10));
              }
            } catch (_) {}
          } catch (_) {}
        }
      }

      // 2) Web 逆地理兜底（需要 Web 服务 AK 权限/IP 白名单；失败时输出中文诊断日志）。
      // Web 逆地理：使用 Web AK
      String ak = '';
      try { ak = await ConfigDao().getBaiduAk(); } catch (_) { ak = ''; }
      final effectiveAk = ak.trim().isNotEmpty ? ak.trim() : 'kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2';
      final url = Uri.parse(
        'https://api.map.baidu.com/reverse_geocoding/v3/?ak=${Uri.encodeComponent(effectiveAk)}&coordtype=wgs84ll&extensions_poi=1&radius=600&location=${pos.latitude},${pos.longitude}'
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && (data['status'] == 0 || data['status'] == '0')) {
          final result = data['result'];
          if (result is Map) {
            final pois = result['pois'];
            if (pois is List && pois.isNotEmpty) {
              final first = pois.first;
              String? name; int? distance;
              if (first is Map) {
                final n = first['name']; final d = first['distance'];
                if (n is String) name = n; if (d is int) distance = d;
              }
              if (name != null) {
                final suffix = distance != null ? '（约' + distance.toString() + '米）' : '';
                try { await DLog.i('LocationService', '附近地标：' + name + suffix); } catch (_) {}
              }
            }
            if (pois is List && pois.isEmpty) {
              try { await DLog.w('LocationService', '【定位】Web逆地理返回成功但无POI'); } catch (_) {}
            }
          }
        } else if (data is Map) {
          try {
            await DLog.w(
              'LocationService',
              '【定位】Web逆地理返回错误 status=${data['status']}, msg=${data['msg']}',
            );
          } catch (_) {}
        }
      } else {
        try { await DLog.w('LocationService', '【定位】Web逆地理HTTP失败 status=${res.statusCode}'); } catch (_) {}
      }
    } catch (_) {}
  }

  /// 通过系统逆地理服务获取附近标记。若反向地理编码失败，则返回空列表。
  ///
  /// 由于系统 API 无法提供与百度接口类似的 POI 列表，故此方法仅返回当前位置的名称
  ///（如果能够解析），并将距离字段设为 0。

/// 使用「系统定位」获得的坐标，再通过系统 Geocoder 获取附近地标（分页 + 关键字过滤）。
///
/// 注意：系统 Geocoder 不会返回与百度一致的 POI 列表与距离字段，因此这里主要用于：
/// - 在 Baidu Web API 网络不可用时，给“新增地点规则”弹窗提供一个可用的地点名称兜底；
/// - 支持 keyword 过滤与 page/pageSize 分页，以匹配 UI 的“搜索/加载更多”行为。
static Future<Position?> _getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) {
        try {
          await DLog.w(
            'LocationService',
            '【定位】lastKnown 位置为空',
          );
        } catch (_) {}
        return null;
      }
      try {
        await DLog.i(
          'LocationService',
          '【定位】lastKnown 成功 acc=${pos.accuracy}m, lat=${pos.latitude}, lon=${pos.longitude}',
        );
      } catch (_) {}
      return pos;
    } catch (e) {
      try {
        await DLog.w(
          'LocationService',
          '【定位】lastKnown 调用异常：$e',
        );
      } catch (_) {}
      return null;
    }
  }

static Future<Position?> _baiduSdkLocationWithRetry(int maxAttempts, {bool strict = false}) async {
    Position? last;
    for (var i = 0; i < maxAttempts; i++) {
      last = await _baiduSdkLocationOnce();
      if (last == null) {
        // 插件异常等情况，_baiduSdkLocationOnce 内部已经写日志，这里直接结束重试。
        break;
      }
      final ok = last.accuracy <= _desiredAccuracyMeters;
      if (ok) {
        // 精度已满足要求，直接返回
        return last;
      } else {
        try {
          await DLog.w(
            'LocationService',
            '【定位】Baidu SDK 第${i + 1}次精度不满足要求 acc=${last.accuracy.toStringAsFixed(3)}m (>=${_desiredAccuracyMeters.toStringAsFixed(1)}m)，准备${i + 1 < maxAttempts ? '重试一次' : '结束重试'}',
          );
        } catch (_) {}
        if (i + 1 < maxAttempts) {
          // 适当延时 0.5s 再进行下一次尝试，提升 30m 精度的稳定性
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return last;
  }

static Future<List<PoiItem>> fetchNearbyPoisSystem({
  required double latitude,
  required double longitude,
  int radiusMeters = 100,
  String keyword = '',
  int page = 1,
  int pageSize = 5,
}) async {
  try {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) return const <PoiItem>[];

    final List<PoiItem> all = [];
    for (final p in placemarks) {
      final parts = <String>[
        p.country ?? '',
        p.administrativeArea ?? '',
        p.locality ?? '',
        p.subLocality ?? '',
        p.thoroughfare ?? '',
        p.subThoroughfare ?? '',
        p.name ?? '',
      ];
      final addr = parts.where((e) => e.isNotEmpty).join('');
      final name = (p.name ?? '').isNotEmpty ? (p.name ?? '') : addr;

      all.add(
        PoiItem(
          name: name.isEmpty ? '未知地点' : name,
          address: addr.isEmpty ? null : addr,
          latitude: latitude,
          longitude: longitude,
          distance: null,
        ),
      );
    }

    // 关键字过滤
    if (keyword.isNotEmpty) {
      final kw = keyword.toLowerCase();
      all.retainWhere((poi) {
        final text = (poi.name + (poi.address ?? '')).toLowerCase();
        return text.contains(kw);
      });
    }
    if (all.isEmpty) return const <PoiItem>[];

    // 最终去重：仅按名称唯一（严格）—— 同名只保留一条
    final list = _dedupByNameStrict(all);

    // 分页：page 从 1 开始
    if (page <= 0) page = 1;
    if (pageSize <= 0) pageSize = 10;
    final start = (page - 1) * pageSize;
    if (start >= list.length) return const <PoiItem>[];
    final end = start + pageSize;
    return list.sublist(start, end > list.length ? list.length : end);
  } catch (e) {
    try {
      await DLog.w('LocationService', '【定位】系统逆地理获取附近地标失败：$e');
    } catch (_) {}
    return const <PoiItem>[];
  }
}

// ---------------------------------------------------------------------------
// 内部：Baidu Web 逆地理 + POI 查询（用于“新增地点规则”弹窗）
// ---------------------------------------------------------------------------

/// 兜底：当 Baidu 逆地理没有返回 POI 时，使用 Place Search API 做圆形检索（返回更丰富的业态列表）
static Future<List<PoiItem>> _fetchPoisFromBaiduPlaceApi({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String keyword = '',
  }) async {
  // 半径范围保护：默认 50m，最大 3000m。
  final radius = radiusMeters <= 0 ? 50 : (radiusMeters > 3000 ? 3000 : radiusMeters);

  final q = keyword.trim();
  // Place Search API 要求 query/tag 至少其一非空；否则会返回 status=2 Parameter Invalid。
  // 在新增地点规则弹窗默认 keyword 为空的场景，我们直接返回空列表，让上层走系统逆地理兜底。
  if (q.isEmpty) {
    return const <PoiItem>[];
  }

  String ak;
  try {
    ak = (await ConfigDao().getBaiduAk()).trim();
  } catch (_) {
    ak = '';
  }
  if (ak.isEmpty) {
    try {
      await DLog.w('LocationService', '【定位】未配置 Baidu AK，无法通过 Place API 查询附近 POI');
    } catch (_) {}
    return const <PoiItem>[];
  }

  final params = <String, String>{
    'ak': ak,
    'output': 'json',
    // 传入坐标类型：1 = WGS84，经纬度
    'coord_type': '1',
    'location': '$latitude,$longitude',
    'radius': radius.toString(),
    'scope': '2',
    'page_size': '50',
    'page_num': '0',
    // query 为必填：用关键字做周边检索。
    'query': q,
  };

  final uri = Uri.parse(
    'https://api.map.baidu.com/place/v2/search?' +
        params.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&'),
  );

  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      try {
        await DLog.w('LocationService', '【定位】Baidu Place HTTP ${resp.statusCode}');
      } catch (_) {}
      return const <PoiItem>[];
    }

    final body = resp.body;
    final trimmedBody = body.trimLeft();
    if (trimmedBody.startsWith('<')) {
      try {
        await DLog.w('LocationService', '【定位】Baidu API 返回非 JSON（疑似 XML/HTML），已忽略');
      } catch (_) {}
      return const <PoiItem>[];
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      try {
        await DLog.w('LocationService', '【定位】Baidu API JSON 解析失败，已忽略');
      } catch (_) {}
      return const <PoiItem>[];
    }
    final status = (data['status'] as num?)?.toInt() ?? -1;
    if (status != 0) {
      try {
        final errMsg = (data['message'] ?? data['msg'] ?? '').toString();
        await DLog.w('LocationService', '【定位】Baidu Place 返回错误：status=$status, msg=$errMsg');
      } catch (_) {}
      return const <PoiItem>[];
    }

    final list = <PoiItem>[];
    final results = data['results'];
    if (results is List) {
      for (final raw in results) {
        if (raw is! Map) continue;
        final m = raw.map((k, v) => MapEntry(k.toString(), v));

        final name = (m['name'] ?? '').toString();
        final addr = (m['address'] ?? '').toString();

        double? lat;
        double? lng;
        final loc = m['location'];
        if (loc is Map) {
          lat = (loc['lat'] as num?)?.toDouble();
          lng = (loc['lng'] as num?)?.toDouble();
        }
        lat ??= latitude;
        lng ??= longitude;

        list.add(
          PoiItem(
            name: name.isEmpty ? '未知地点' : name,
            address: addr.isEmpty ? null : addr,
            latitude: lat,
            longitude: lng,
            distance: null,
          ),
        );
      }
    }

    return list;
  } on TimeoutException catch (e) {
    try {
      await DLog.w('LocationService', '【定位】Baidu Place 请求超时：$e');
    } catch (_) {}
    return const <PoiItem>[];
  } catch (e) {
    try {
      await DLog.w('LocationService', '【定位】Baidu Place 调用异常：$e');
    } catch (_) {}
    return const <PoiItem>[];
  }
}


  
  static Future<List<PoiItem>> _fetchNearbyPoisFromBaiduSdkReverse({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    try {
      final ret = await _sysCh.invokeMethod('reverseGeocodePoisBaiduSdk', {
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        // 坐标系一致性：Baidu GeoCoder 默认使用 BD09LL。
        // 若当前位置来自系统定位，则按 GPS(WGS84) 转换为 BD09LL 后再做逆地理。
        'coordType': (lastProvider == 'baidu') ? 'bd09ll' : 'gps',
      });
      if (ret is Map) {
        final pois = ret['pois'];
        if (pois is List) {
          final out = <PoiItem>[];
          for (final e in pois) {
            if (e is Map) {
              final name = (e['name'] as String?) ?? '';
              final addr = (e['address'] as String?) ?? '';
              final lat = (e['lat'] as num?)?.toDouble();
              final lng = (e['lng'] as num?)?.toDouble();
              final dist = (e['distance'] as num?)?.toDouble();
              if (name.isNotEmpty && lat != null && lng != null) {
                out.add(PoiItem(name: name, address: addr, latitude: lat, longitude: lng, distance: dist?.round()));
              }
            }
          }
          // 防御性处理：按距离排序，并严格过滤 radius 内 POI
          out.sort((a, b) => (a.distance ?? 1 << 30).compareTo(b.distance ?? 1 << 30));
          final r = radiusMeters <= 0 ? 50 : radiusMeters;
          return out.where((p) => p.distance == null || p.distance! <= r).toList();
        }
      }
    } catch (_) {}
    return const <PoiItem>[];
  }

  /// Baidu Map Search SDK 周边检索：用于补充 reverseGeocode.poiList 召回不足的情况。
  ///
  /// 说明：Baidu SDK 的“周边检索”需要 keyword 才能检索，因此这里做“多关键字”组合，
  /// 以覆盖：公司/餐饮/住宿/商店等常见场景。
  static Future<List<PoiItem>> _fetchNearbyPoisFromBaiduSdkNearbySearch({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    List<String>? keywords,
  }) async {
    final kws = (keywords == null || keywords.isEmpty)
        ? const <String>[
            '公司',
            '餐厅',
            '酒店',
            '商店',
            '超市',
            '便利店',
          ]
        : keywords;

    try {
      final ret = await _sysCh.invokeMethod('searchNearbyPoisBaiduSdk', {
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
        'coordType': (lastProvider == 'baidu') ? 'bd09ll' : 'gps',
        'keywords': kws,
      });
      if (ret is Map) {
        final pois = ret['pois'];
        if (pois is List) {
          final out = <PoiItem>[];
          for (final e in pois) {
            if (e is Map) {
              final name = (e['name'] as String?) ?? '';
              final addr = (e['address'] as String?) ?? '';
              final lat = (e['lat'] as num?)?.toDouble();
              final lng = (e['lng'] as num?)?.toDouble();
              final dist = (e['distance'] as num?)?.toDouble();
              if (name.isNotEmpty && lat != null && lng != null) {
                out.add(
                  PoiItem(
                    name: name,
                    address: addr.isEmpty ? null : addr,
                    latitude: lat,
                    longitude: lng,
                    distance: dist?.round(),
                  ),
                );
              }
            }
          }
          out.sort((a, b) => (a.distance ?? 1 << 30).compareTo(b.distance ?? 1 << 30));
          final r = radiusMeters <= 0 ? 50 : radiusMeters;
          return out.where((p) => p.distance == null || p.distance! <= r).toList();
        }
      }
    } catch (_) {}

    return const <PoiItem>[];
  }

static Future<List<PoiItem>> _fetchNearbyPoisFromBaiduApi({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    String ak;
    try {
      ak = (await ConfigDao().getBaiduAk()).trim();
    } catch (_) {
      ak = '';
    }
    if (ak.isEmpty) return const <PoiItem>[];

    final radius = radiusMeters.clamp(50, 1000);

	    Future<List<PoiItem>> _callOnce(String coordtype, String retCoordtype) async {
	      final params = <String, String>{
        'ak': ak,
        'output': 'json',
        'coordtype': coordtype,
        'location': '$latitude,$longitude',
        'extensions_poi': '1',
        'radius': radius.toString(),
        // 一次最多拉较多 poi，后续在内存中做分页。
        'page_size': '50',
        'page_num': '0',
      };

	      // 官方文档：ret_coordtype 仅支持部分值（例如 gcj02ll / bd09mc），默认返回 bd09ll。
	      // 为提升兼容性，这里只在明确需要且被支持时再透传。
	      final rct = retCoordtype.trim().toLowerCase();
	      if (rct == 'gcj02ll' || rct == 'bd09mc') {
	        params['ret_coordtype'] = rct;
	      }

      final uri = Uri.parse(
        'https://api.map.baidu.com/reverse_geocoding/v3/?' +
            params.entries
                .map((e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
                .join('&'),
      );

      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) {
          try {
            await DLog.w('LocationService', '【定位】Baidu 逆地理 HTTP ${resp.statusCode}');
          } catch (_) {}
          return const <PoiItem>[];
        }
        final body = resp.body.trimLeft();
        if (body.startsWith('<')) {
          // 避免 XML/HTML 被当成 JSON 解析
          return const <PoiItem>[];
        }
        final js = json.decode(resp.body);
        if (js is! Map) return const <PoiItem>[];
        final status = js['status'];
        if (status != 0 && status != '0') {
          try {
            await DLog.w('LocationService', '【定位】Baidu 逆地理返回错误: status=$status, msg=${js['msg']}');
          } catch (_) {}
          return const <PoiItem>[];
        }

        final result = js['result'];
        if (result is! Map) return const <PoiItem>[];
        final pois = result['pois'];
        if (pois is! List) return const <PoiItem>[];

        final out = <PoiItem>[];
        for (final p in pois) {
          if (p is! Map) continue;
          final name = (p['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;

          double? lat;
          double? lng;
          final pt = p['point'];
          if (pt is Map) {
            lat = (pt['y'] as num?)?.toDouble();
            lng = (pt['x'] as num?)?.toDouble();
          } else {
            // v3 返回里部分字段可能直接是 location
            final loc = p['location'];
            if (loc is Map) {
              lat = (loc['lat'] as num?)?.toDouble();
              lng = (loc['lng'] as num?)?.toDouble();
            }
          }
          if (lat == null || lng == null) continue;

          final address = (p['addr'] as String?)?.trim() ?? '';
          out.add(PoiItem(
            name: name,
            address: address,
            latitude: lat,
            longitude: lng,
          ));
        }
        return out;
      } on TimeoutException catch (e) {
        try {
          await DLog.w('LocationService', '【定位】Baidu 逆地理请求超时：$e');
        } catch (_) {}
        return const <PoiItem>[];
      } catch (e) {
        try {
          await DLog.w('LocationService', '【定位】Baidu 逆地理异常：$e');
        } catch (_) {}
        return const <PoiItem>[];
      }
    }

    // 坐标系选择：
    // - 如果刚才的定位来自百度SDK，则经纬度多为 bd09ll；
    // - 系统定位/Geolocator 更接近 wgs84ll（不同机型在国内也可能接近 gcj02ll）。
    final provider = lastProvider ?? '';
    final preferred = provider == 'baidu' ? 'bd09ll' : 'wgs84ll';

    // 先按“最可能正确”的坐标系请求；若没有召回 POI，再做轻量兜底尝试。
    final candidates = <String>[
      preferred,
      if (preferred != 'gcj02ll') 'gcj02ll',
      if (preferred != 'bd09ll') 'bd09ll',
    ];

    for (final ct in candidates) {
      final r = await _callOnce(ct, ct);
      if (r.isNotEmpty) return r;
    }
    return const <PoiItem>[];
  }


/// 页面“新增地点规则”需要的 POI 拉取：优先 Baidu 逆地理（50m 内 POI），
/// 若逆地理未返回任何 POI，则兜底使用 Place Search API。
  /// 页面“新增地点规则”需要的 POI 拉取：优先 Baidu 逆地理（严格 radius 内 POI）。
  ///
  /// 注意：为了满足“50m 内”的强约束，这里**不再**把远处 Place Search 结果直接作为兜底列表展示。
  /// 若逆地理无满足半径的 POI：
  /// - keyword 非空：调用 Place Search 后仍会做 <=radius 的二次过滤；
  /// - keyword 为空：仅返回“当前位置”兜底项（distance=0），避免误展示 1km+ 的地点。
  static Future<List<PoiItem>> fetchNearbyPois({
    required double latitude,
    required double longitude,
    int radiusMeters = 100,
    String keyword = '',
    int page = 1,
    int pageSize = 5,
  }) async {
    final radius = radiusMeters <= 0 ? 50 : radiusMeters;

    int haversineMeters(double lat1, double lon1, double lat2, double lon2) {
      const r = 6371000.0;
      final dLat = _degToRad(lat2 - lat1);
      final dLon = _degToRad(lon2 - lon1);
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degToRad(lat1)) *
              math.cos(_degToRad(lat2)) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return (r * c).toInt();
    }

    List<PoiItem> enforceRadius(List<PoiItem> src) {
      final out = <PoiItem>[];
      for (final p in src) {
        final d = haversineMeters(latitude, longitude, p.latitude, p.longitude);
        if (d <= radius) {
          out.add(PoiItem(
            name: p.name,
            address: p.address,
            latitude: p.latitude,
            longitude: p.longitude,
            distance: d,
          ));
        }
      }
      out.sort((a, b) => (a.distance ?? 1 << 30).compareTo(b.distance ?? 1 << 30));
      return out;
    }

    // 1) Baidu Map SDK：先逆地理（poiList），再用「周边检索」补充召回（公司/餐饮/住宿/商店等）。
    // 原生侧会做坐标系转换，这里再做一层防御性 radius 过滤。
    final sdkReverseRaw = await _fetchNearbyPoisFromBaiduSdkReverse(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius,
    );
    var list = enforceRadius(sdkReverseRaw);

    // 1.5) 补充：周边检索（多关键字）。
    // - keyword 为空：默认拉公司/餐厅/酒店/商店等常见 POI；
    // - keyword 非空：用用户关键字做一次 nearby 检索，提升“搜索附近地点”体验。
    try {
      final nearbyRaw = await _fetchNearbyPoisFromBaiduSdkNearbySearch(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        keywords: keyword.trim().isEmpty ? null : <String>[keyword.trim()],
      );
      final nearby = enforceRadius(nearbyRaw);
      if (nearby.isNotEmpty) {
        final seen = <String>{
          for (final p in list) '${p.name}|${p.latitude.toStringAsFixed(6)}|${p.longitude.toStringAsFixed(6)}'
        };
        for (final p in nearby) {
          final k = '${p.name}|${p.latitude.toStringAsFixed(6)}|${p.longitude.toStringAsFixed(6)}';
          if (!seen.contains(k)) {
            seen.add(k);
            list.add(p);
          }
        }
        list.sort((a, b) => (a.distance ?? 1 << 30).compareTo(b.distance ?? 1 << 30));
      }
    } catch (_) {}

	    // 2) 若需要搜索（keyword 非空），允许调用 Place Search，但仍必须满足 <=radius
    if (list.isEmpty && keyword.trim().isNotEmpty) {
      final fromPlace = await _fetchPoisFromBaiduPlaceApi(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        keyword: keyword.trim(),
      );
      list = enforceRadius(fromPlace);
    }

	    // 2.5) SDK 逆地理有概率返回空 poiList（部分机型/SDK 版本/离线场景）。
	    // 为了满足“必须展示 50m 内附近地点”这一核心诉求：
	    // - 仅在 keyword 为空时，追加 Baidu Web 逆地理作为兜底（仍严格 <=radius 过滤）。
	    // - 优先百度定位（bd09ll）场景，避免不同坐标系导致的距离误判。
	    if (list.isEmpty && keyword.trim().isEmpty && (lastProvider ?? '') == 'baidu') {
	      final fromWebReverse = await _fetchNearbyPoisFromBaiduApi(
	        latitude: latitude,
	        longitude: longitude,
	        radiusMeters: radius,
	      );
	      list = enforceRadius(fromWebReverse);
	    }

    // 3) 若仍为空：只返回“当前位置”兜底项（避免展示远处 POI）
    if (list.isEmpty) {
      list = <PoiItem>[
        PoiItem(
          name: '当前位置',
          address: null,
          latitude: latitude,
          longitude: longitude,
          distance: 0,
        ),
      ];
    }

    // 最终去重（前端展示前）：仅按名称唯一（严格）—— 同名只保留一条（保留距离更近的那条）
    list = _dedupByNameStrict(list);

    
    /// 去重：名称唯一（严格）—— 同名只保留一条
    list = _dedupByNameStrict(list);
// 分页
    final _page = page <= 0 ? 1 : page;
    final _pageSize = pageSize <= 0 ? 10 : pageSize;
    final startIdx = (_page - 1) * _pageSize;
    if (startIdx >= list.length) return const <PoiItem>[];
    final endIdx = (startIdx + _pageSize) > list.length ? list.length : (startIdx + _pageSize);
    return list.sublist(startIdx, endIdx);
  }

  
  /// 最终去重（前端展示前）：
  /// 只按 “地点名称 + 坐标(保留到6位小数)” 去重，确保不会出现名称且坐标都相同的地点。
  static List<PoiItem> _dedupByNameAndCoordExact(List<PoiItem> src) {
    if (src.length <= 1) return src;
    final out = <PoiItem>[];
    final seen = <String>{};

    String keyOf(PoiItem p) {
      final name = (p.name).trim();
      final lat = p.latitude.toStringAsFixed(6);
      final lng = p.longitude.toStringAsFixed(6);
      return '$name|$lat|$lng';
    }

    for (final p in src) {
      final k = keyOf(p);
      if (seen.add(k)) {
        out.add(p);
      }
    }
    return out;
  }

static double _degToRad(double deg) => deg * math.pi / 180.0;
}