// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "AppDelegate.h"
#import <Flutter/Flutter.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>
#import "GeneratedPluginRegistrant.h"

@interface AppDelegate () <FlutterPluginRegistrant, CLLocationManagerDelegate, UNUserNotificationCenterDelegate> {
FlutterEventSink _eventSink;
  FlutterMethodChannel* _sysChannel;

  // Sport notification UI (iOS local notification)
  NSString* _sportTitle;
  NSString* _sportTargetType;
  double _sportTargetValue;
  NSString* _sportTargetUnit;
  NSTimeInterval _lastNotifUpdateTs;

  // Sport native tracking (iOS)
  CLLocationManager* _locMgr;
  CLLocation* _lastLoc;
  NSTimeInterval _lastLocTs;
  NSTimer* _sportTimer;
  BOOL _sportRunning;
  int _sportRecordId;
  NSTimeInterval _startTs;
  int _baseDurationSec;
  double _baseDistanceM;
  int _baseSteps;
  double _sessionDistanceM;
  double _currentSpeedKmh;
  // Drift suppression & snapshot throttling (iOS)
  CLLocation* _pendingLoc;
  double _pendingDistanceM;
  int _pendingCount;
  int _stationaryStreak;
  NSTimeInterval _lastSnapshotSyncTs;

}
@end

@implementation AppDelegate (SportNative)
#pragma mark - Sport Native Tracking (iOS)


// Pending notification tap delivery to Flutter (cold start safety)
- (NSString*)_pendingNotifKey {
  return @"quoteapp_pending_notif_tap";
}

- (void)_savePendingNotifTap:(NSDictionary*)args {
  if (args == nil) return;
  [[NSUserDefaults standardUserDefaults] setObject:args forKey:[self _pendingNotifKey]];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary*)_loadPendingNotifTap {
  id v = [[NSUserDefaults standardUserDefaults] objectForKey:[self _pendingNotifKey]];
  if (![v isKindOfClass:[NSDictionary class]]) return nil;
  return (NSDictionary*)v;
}

- (void)_clearPendingNotifTap {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self _pendingNotifKey]];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString*)_formatDuration:(int)sec {
  int s = MAX(0, sec);
  int h = s / 3600;
  int m = (s % 3600) / 60;
  int ss = s % 60;
  return [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, ss];
}

- (NSString*)_buildSportNotifLine:(NSDictionary*)snap {
  if (snap == nil) return @"";
  NSString* status = [snap[@"status"] isKindOfClass:[NSString class]] ? snap[@"status"] : @"in_progress";
  int dur = [snap[@"total_duration"] respondsToSelector:@selector(intValue)] ? [snap[@"total_duration"] intValue] : 0;
  double distM = [snap[@"total_distance"] respondsToSelector:@selector(doubleValue)] ? [snap[@"total_distance"] doubleValue] : 0.0;
  int steps = [snap[@"total_steps"] respondsToSelector:@selector(intValue)] ? [snap[@"total_steps"] intValue] : 0;

  NSString* prefix = [status isEqualToString:@"paused"] ? @"已暂停 · " : @"";
  NSString* timeStr = [self _formatDuration:dur];

  // A原则：有目标就显示进度/目标，无目标显示距离+时间
  if (_sportTargetType != nil && _sportTargetType.length > 0 && _sportTargetValue > 0.0) {
    if ([_sportTargetType isEqualToString:@"steps"]) {
      int tv = (int)llround(_sportTargetValue);
      NSString* unit = (_sportTargetUnit != nil && _sportTargetUnit.length > 0) ? _sportTargetUnit : @"步";
      if (tv > 0) {
        return [NSString stringWithFormat:@"%@%d / %d %@ · %@", prefix, steps, tv, unit, timeStr];
      }
    } else if ([_sportTargetType isEqualToString:@"distance"]) {
      double km = distM / 1000.0;
      NSString* unit = (_sportTargetUnit != nil && _sportTargetUnit.length > 0) ? _sportTargetUnit : @"km";
      return [NSString stringWithFormat:@"%@%.2f %@ / %.2f %@ · %@", prefix, km, unit, _sportTargetValue, unit, timeStr];
    } else if ([_sportTargetType isEqualToString:@"duration"]) {
      // targetValue uses hours (from plan edit)
      int targetSec = (int)MAX(0, llround(_sportTargetValue * 3600.0));
      if (targetSec > 0) {
        return [NSString stringWithFormat:@"%@%@ / %@", prefix, [self _formatDuration:dur], [self _formatDuration:targetSec]];
      }
    }
  }

  double km = distM / 1000.0;
  return [NSString stringWithFormat:@"%@%.2f km · %@", prefix, km, timeStr];
}

- (NSString*)_sportNotifIdentifier {
  if (_sportRecordId <= 0) return @"quoteapp_sport_running_0";
  return [NSString stringWithFormat:@"quoteapp_sport_running_%d", _sportRecordId];
}

- (void)_setupSportNotificationCategories {
  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
  center.delegate = self;

  UNNotificationAction* pauseAction =
      [UNNotificationAction actionWithIdentifier:@"SPORT_PAUSE" title:@"暂停" options:UNNotificationActionOptionNone];
  UNNotificationAction* resumeAction =
      [UNNotificationAction actionWithIdentifier:@"SPORT_RESUME" title:@"继续" options:UNNotificationActionOptionNone];

  UNNotificationCategory* catActive =
      [UNNotificationCategory categoryWithIdentifier:@"SPORT_RUNNING_ACTIVE"
                                           actions:@[ pauseAction ]
                                 intentIdentifiers:@[]
                                           options:UNNotificationCategoryOptionCustomDismissAction];

  UNNotificationCategory* catPaused =
      [UNNotificationCategory categoryWithIdentifier:@"SPORT_RUNNING_PAUSED"
                                           actions:@[ resumeAction ]
                                 intentIdentifiers:@[]
                                           options:UNNotificationCategoryOptionCustomDismissAction];

  NSSet* cats = [NSSet setWithObjects:catActive, catPaused, nil];
  [center setNotificationCategories:cats];
}

- (void)_updateSportLocalNotification {
  if (_sportRecordId <= 0) return;

  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];

  NSDictionary* snap = [self _sportSnapshot];
  NSString* status = [snap[@"status"] isKindOfClass:[NSString class]] ? snap[@"status"] : @"in_progress";
  NSString* line = [self _buildSportNotifLine:snap];
  if (line == nil) line = @"";

  // throttle updates to avoid spamming
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  if (_lastNotifUpdateTs > 0 && (now - _lastNotifUpdateTs) < 10.0) {
    return;
  }
  _lastNotifUpdateTs = now;

  UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
  content.title = (_sportTitle != nil && _sportTitle.length > 0) ? _sportTitle : @"运动进行中";
  content.body = line;
  content.sound = nil;
  content.threadIdentifier = @"quoteapp_sport_running";
  content.categoryIdentifier = [status isEqualToString:@"paused"] ? @"SPORT_RUNNING_PAUSED" : @"SPORT_RUNNING_ACTIVE";
  content.userInfo = @{
    @"type": @"sport_running",
    @"payload": [NSString stringWithFormat:@"{\"recordId\":%d}", _sportRecordId],
  };

  if (@available(iOS 15.0, *)) {
    content.interruptionLevel = UNNotificationInterruptionLevelPassive;
  }

  NSString* ident = [self _sportNotifIdentifier];

  // Keep only one notification visible by removing previous then adding.
  [center removeDeliveredNotificationsWithIdentifiers:@[ ident ]];
  [center removePendingNotificationRequestsWithIdentifiers:@[ ident ]];

  UNNotificationRequest* req = [UNNotificationRequest requestWithIdentifier:ident content:content trigger:nil];
  [center addNotificationRequest:req withCompletionHandler:^(NSError* _Nullable error) {
    // ignore
  }];
}

- (void)_removeSportLocalNotification {
  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
  NSString* ident = [self _sportNotifIdentifier];
  [center removeDeliveredNotificationsWithIdentifiers:@[ ident ]];
  [center removePendingNotificationRequestsWithIdentifiers:@[ ident ]];
}

- (void)_emitNotifTapToFlutterIfPossible:(NSDictionary*)args {
  if (args == nil) return;
  if (_sysChannel != nil) {
    [_sysChannel invokeMethod:@"onNativeNotificationTap" arguments:args];
  } else {
    [self _savePendingNotifTap:args];
  }
}

- (void)_emitPendingNotifTapIfAny {
  NSDictionary* pending = [self _loadPendingNotifTap];
  if (pending == nil) return;
  [self _clearPendingNotifTap];
  if (_sysChannel != nil) {
    [_sysChannel invokeMethod:@"onNativeNotificationTap" arguments:pending];
  }
}


- (NSString*)_sportSnapshotKey:(int)recordId {
  return [NSString stringWithFormat:@"quoteapp_sport_fg_%d", recordId];
}

- (NSDictionary*)_loadSportSnapshot:(int)recordId {
  NSString* key = [self _sportSnapshotKey:recordId];
  NSDictionary* d = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (![d isKindOfClass:[NSDictionary class]]) return nil;
  return d;
}

- (void)_saveSportSnapshot:(NSDictionary*)snapshot recordId:(int)recordId {
  [self _saveSportSnapshot:snapshot recordId:recordId forceSync:YES];
}

- (void)_saveSportSnapshot:(NSDictionary*)snapshot recordId:(int)recordId forceSync:(BOOL)forceSync {
  if (recordId <= 0 || snapshot == nil) return;
  NSString* key = [self _sportSnapshotKey:recordId];
  NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
  [ud setObject:snapshot forKey:key];

  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  BOOL shouldSync = forceSync;
  if (!shouldSync) {
    if (_lastSnapshotSyncTs <= 0 || (now - _lastSnapshotSyncTs) >= 3.0) {
      shouldSync = YES;
    }
  }
  if (shouldSync) {
    [ud synchronize];
    _lastSnapshotSyncTs = now;
  }
}

- (int)_currentDurationSec {
  if (!_sportRunning) return _baseDurationSec;
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  int inc = (int)MAX(0, floor(now - _startTs));
  return _baseDurationSec + inc;
}

- (NSDictionary*)_sportSnapshot {
  int dur = [self _currentDurationSec];
  double dist = _baseDistanceM + _sessionDistanceM;
  int steps = _baseSteps + (int)llround(_sessionDistanceM / 0.75); // rough step length
  double avg = (dur > 0) ? (dist / (double)dur) * 3.6 : 0.0;
  return @{
    @"status": (_sportRunning ? @"in_progress" : @"paused"),
    @"total_duration": @(dur),
    @"total_distance": @(dist),
    @"total_steps": @(steps),
    @"current_speed": @(_currentSpeedKmh),
    @"avg_speed": @(avg),
  };
}

- (BOOL)_sportIsRunning {
  return _sportRunning;
}

- (void)_sportStart:(int)recordId {
  if (recordId <= 0) return;

  // Load previous snapshot as base (so leaving page / relaunch won't lose data).
  NSDictionary* snap = [self _loadSportSnapshot:recordId];
  _baseDurationSec = [snap[@"total_duration"] respondsToSelector:@selector(intValue)] ? [snap[@"total_duration"] intValue] : 0;
  _baseDistanceM = [snap[@"total_distance"] respondsToSelector:@selector(doubleValue)] ? [snap[@"total_distance"] doubleValue] : 0.0;
  _baseSteps = [snap[@"total_steps"] respondsToSelector:@selector(intValue)] ? [snap[@"total_steps"] intValue] : 0;

  _sportRecordId = recordId;
  _sessionDistanceM = 0.0;
  _currentSpeedKmh = 0.0;
  _lastLoc = nil;
  _lastLocTs = 0;
  _pendingLoc = nil;
  _pendingDistanceM = 0.0;
  _pendingCount = 0;
  _stationaryStreak = 0;
  _lastSnapshotSyncTs = 0;

  _startTs = [[NSDate date] timeIntervalSince1970];
  _sportRunning = YES;
  _lastNotifUpdateTs = 0;
  [self _updateSportLocalNotification];

  if (_locMgr == nil) {
    _locMgr = [[CLLocationManager alloc] init];
    _locMgr.delegate = self;
    _locMgr.desiredAccuracy = kCLLocationAccuracyBest;
    _locMgr.distanceFilter = 1.0;
    _locMgr.pausesLocationUpdatesAutomatically = NO;
    if ([_locMgr respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)]) {
      _locMgr.allowsBackgroundLocationUpdates = YES;
    }
  }

  // Try request authorization. (User still needs to grant in Settings.)
  if ([_locMgr respondsToSelector:@selector(requestAlwaysAuthorization)]) {
    [_locMgr requestAlwaysAuthorization];
  } else if ([_locMgr respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
    [_locMgr requestWhenInUseAuthorization];
  }

  [_locMgr startUpdatingLocation];

  [_sportTimer invalidate];
  _sportTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                 target:self
                                               selector:@selector(_sportTick)
                                               userInfo:nil
                                                repeats:YES];
  // Give the system a little scheduling flexibility for better battery life.
  _sportTimer.tolerance = 0.2;


  // Persist immediately.
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId];
  [self _updateSportLocalNotification];
}

- (void)_sportStop {
  if (_sportRecordId <= 0) {
    _sportRunning = NO;
    return;
  }

  // Freeze current segment into base so UI/notification won't keep ticking after pause.
  int dur = [self _currentDurationSec];
  double dist = _baseDistanceM + _sessionDistanceM;
  int steps = _baseSteps + (int)llround(_sessionDistanceM / 0.75);
  double avg = (dur > 0) ? (dist / (double)dur) * 3.6 : 0.0;

  _baseDurationSec = dur;
  _baseDistanceM = dist;
  _baseSteps = steps;
  _sessionDistanceM = 0.0;
  _currentSpeedKmh = 0.0;
  _startTs = [[NSDate date] timeIntervalSince1970];
  _sportRunning = NO;

  _lastLoc = nil;
  _lastLocTs = 0;
  _pendingLoc = nil;
  _pendingDistanceM = 0.0;
  _pendingCount = 0;
  _stationaryStreak = 0;

  if (_locMgr != nil) {
    [_locMgr stopUpdatingLocation];
  }
  [_sportTimer invalidate];
  _sportTimer = nil;

  NSDictionary* out = @{
    @"status": @"paused",
    @"total_duration": @(dur),
    @"total_distance": @(dist),
    @"total_steps": @(steps),
    @"current_speed": @(0.0),
    @"avg_speed": @(avg),
  };
  _lastNotifUpdateTs = 0;
  [self _saveSportSnapshot:out recordId:_sportRecordId forceSync:YES];
  [self _updateSportLocalNotification];
}


- (void)_sportTick {
  if (!_sportRunning) return;
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId forceSync:NO];
  [self _updateSportLocalNotification];
}


- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
  if (!_sportRunning || locations.count == 0) return;
  CLLocation* loc = [locations lastObject];

  // Ignore poor accuracy fixes.
  if (loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 80) return;

  NSTimeInterval ts = [loc.timestamp timeIntervalSince1970];

  if (_lastLoc == nil) {
    _lastLoc = loc;
    _lastLocTs = ts;
    _pendingLoc = nil;
    _pendingDistanceM = 0.0;
    _pendingCount = 0;
    _stationaryStreak = 0;
    return;
  }

  double d = [loc distanceFromLocation:_lastLoc];
  if (d < 0 || d > 2000) {
    _lastLoc = loc;
    _lastLocTs = ts;
    _pendingLoc = nil;
    _pendingDistanceM = 0.0;
    _pendingCount = 0;
    _stationaryStreak = 0;
    return;
  }

  double acc = MAX(0.0, loc.horizontalAccuracy);
  double threshold = acc * 1.2;
  if (threshold < 3.0) threshold = 3.0;
  if (threshold > 25.0) threshold = 25.0;

  // Treat tiny moves as drift when likely stationary.
  if (d < threshold) {
    _stationaryStreak += 1;
    if (_stationaryStreak >= 3) {
      _lastLoc = loc;
      _lastLocTs = ts;
    }
    _pendingLoc = nil;
    _pendingDistanceM = 0.0;
    _pendingCount = 0;
    if (loc.speed >= 0) {
      _currentSpeedKmh = loc.speed * 3.6;
    }
  } else {
    _stationaryStreak = 0;
    BOOL confirmed = NO;

    // Confirm movement: speed indicates, or two consecutive offsets accumulate beyond threshold.
    if (loc.speed >= 0.7) {
      confirmed = YES;
    } else {
      if (_pendingLoc == nil) {
        _pendingLoc = loc;
        _pendingDistanceM = d;
        _pendingCount = 1;
      } else {
        _pendingDistanceM += [loc distanceFromLocation:_pendingLoc];
        _pendingLoc = loc;
        _pendingCount += 1;
      }
      if (_pendingCount >= 2 && _pendingDistanceM >= threshold) {
        confirmed = YES;
      }
    }

    if (confirmed) {
      _sessionDistanceM += d;
      double dt = ts - _lastLocTs;
      if (loc.speed >= 0) {
        _currentSpeedKmh = loc.speed * 3.6;
      } else if (dt > 0.2) {
        _currentSpeedKmh = (d / dt) * 3.6;
      }
      _lastLoc = loc;
      _lastLocTs = ts;
      _pendingLoc = nil;
      _pendingDistanceM = 0.0;
      _pendingCount = 0;
    }
  }

  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId forceSync:NO];
}


@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  self.pluginRegistrant = self;
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [GeneratedPluginRegistrant registerWithRegistry:registry];
  NSObject<FlutterPluginRegistrar>* registrar = [registry registrarForPlugin:@"samples.flutter.io"];
  FlutterMethodChannel* batteryChannel = [FlutterMethodChannel
      methodChannelWithName:@"samples.flutter.io/battery"
            binaryMessenger:registrar.messenger];
  __weak typeof(self) weakSelf = self;
  [batteryChannel setMethodCallHandler:^(FlutterMethodCall* call,
                                         FlutterResult result) {
    if ([@"getBatteryLevel" isEqualToString:call.method]) {
      int batteryLevel = [weakSelf getBatteryLevel];
      if (batteryLevel == -1) {
        result([FlutterError errorWithCode:@"UNAVAILABLE"
                                   message:@"Battery info unavailable"
                                   details:nil]);
      } else {
        result(@(batteryLevel));
      }
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];

  FlutterEventChannel* chargingChannel = [FlutterEventChannel
      eventChannelWithName:@"samples.flutter.io/charging"
           binaryMessenger:registrar.messenger];
  [chargingChannel setStreamHandler:self];

  // QuoteApp sport native tracking channel (shared with Android).
  NSObject<FlutterPluginRegistrar>* sysRegistrar = [registry registrarForPlugin:@"com.example.quote_app.sys"];
  FlutterMethodChannel* sysChannel =
      [FlutterMethodChannel methodChannelWithName:@"com.example.quote_app/sys"
                                  binaryMessenger:sysRegistrar.messenger];
    _sysChannel = sysChannel;
  // Setup notification categories/actions for sport foreground notification
  [self _setupSportNotificationCategories];

__weak typeof(self) weakSelf2 = self;
  [sysChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
    __strong typeof(weakSelf2) strongSelf = weakSelf2;
    if (!strongSelf) {
      result(@(NO));
      return;
    }

    if ([call.method isEqualToString:@"startSportForeground"]) {
      NSDictionary* args = (NSDictionary*)call.arguments;
      NSNumber* rid = args[@"recordId"];
      if (rid == nil) {
        result([FlutterError errorWithCode:@"INVALID_ARGS" message:@"recordId missing" details:nil]);
        return;
      }
      // Optional title/target info for notification UI
id t = args[@"title"];
strongSelf->_sportTitle = [t isKindOfClass:[NSString class]] ? (NSString*)t : @"运动进行中";
id tt = args[@"targetType"];
strongSelf->_sportTargetType = [tt isKindOfClass:[NSString class]] ? (NSString*)tt : nil;
id tv = args[@"targetValue"];
strongSelf->_sportTargetValue = [tv respondsToSelector:@selector(doubleValue)] ? [tv doubleValue] : 0.0;
id tu = args[@"targetUnit"];
strongSelf->_sportTargetUnit = [tu isKindOfClass:[NSString class]] ? (NSString*)tu : nil;

[strongSelf _sportStart:[rid intValue]];
[strongSelf _updateSportLocalNotification];
      result(@(YES));
      return;
    }
    if ([call.method isEqualToString:@"stopSportForeground"]) {
      [strongSelf _sportStop];
[strongSelf _removeSportLocalNotification];
strongSelf->_sportRecordId = 0;
strongSelf->_sportTitle = nil;
strongSelf->_sportTargetType = nil;
strongSelf->_sportTargetValue = 0.0;
strongSelf->_sportTargetUnit = nil;
result(@(YES));
      return;
    }
    if ([call.method isEqualToString:@"pauseSportForeground"]) {
      [strongSelf _sportStop];
      [strongSelf _updateSportLocalNotification];
      result(@(YES));
      return;
    }
    if ([call.method isEqualToString:@"resumeSportForeground"]) {
      NSDictionary* args = (NSDictionary*)call.arguments;
      NSNumber* rid = [args isKindOfClass:[NSDictionary class]] ? args[@"recordId"] : nil;
      int reqId = (rid != nil) ? [rid intValue] : strongSelf->_sportRecordId;
      if (reqId > 0) {
        [strongSelf _sportStart:reqId];
        [strongSelf _updateSportLocalNotification];
        result(@(YES));
      } else {
        result(@(NO));
      }
      return;
    }
    if ([call.method isEqualToString:@"isSportForegroundRunning"]) {
      result(@([strongSelf _sportIsRunning]));
      return;
    }
    if ([call.method isEqualToString:@"getSportSnapshot"]) {
      NSDictionary* args = (NSDictionary*)call.arguments;
      NSNumber* rid = args[@"recordId"];
      int reqId = (rid != nil) ? [rid intValue] : strongSelf->_sportRecordId;

      if (strongSelf->_sportRunning && reqId == strongSelf->_sportRecordId) {
        result([strongSelf _sportSnapshot]);
        return;
      }

      NSDictionary* stored = [strongSelf _loadSportSnapshot:reqId];
      if (stored != nil) {
        result(stored);
      } else {
        result([NSNull null]);
      }
      return;
    }

    result(FlutterMethodNotImplemented);
  }];

  [self _emitPendingNotifTapIfAny];
}


- (int)getBatteryLevel {
  UIDevice* device = UIDevice.currentDevice;
  device.batteryMonitoringEnabled = YES;
  if (device.batteryState == UIDeviceBatteryStateUnknown) {
    return -1;
  } else {
    return ((int)(device.batteryLevel * 100));
  }
}

- (FlutterError*)onListenWithArguments:(id)arguments
                             eventSink:(FlutterEventSink)eventSink {
  _eventSink = eventSink;
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  [self sendBatteryStateEvent];
  [[NSNotificationCenter defaultCenter]
   addObserver:self
      selector:@selector(onBatteryStateDidChange:)
          name:UIDeviceBatteryStateDidChangeNotification
        object:nil];
  return nil;
}

- (void)onBatteryStateDidChange:(NSNotification*)notification {
  [self sendBatteryStateEvent];
}

- (void)sendBatteryStateEvent {
  if (!_eventSink) return;
  UIDeviceBatteryState state = [[UIDevice currentDevice] batteryState];
  switch (state) {
    case UIDeviceBatteryStateFull:
    case UIDeviceBatteryStateCharging:
      _eventSink(@"charging");
      break;
    case UIDeviceBatteryStateUnplugged:
      _eventSink(@"discharging");
      break;
    default:
      _eventSink([FlutterError errorWithCode:@"UNAVAILABLE"
                                     message:@"Charging status unavailable"
                                     details:nil]);
      break;
  }
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _eventSink = nil;
  return nil;
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter*)center
       willPresentNotification:(UNNotification*)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
  // Avoid noisy banners; keep it in notification center list when foreground.
#ifdef UNNotificationPresentationOptionList
  if (@available(iOS 14.0, *)) {
    completionHandler(UNNotificationPresentationOptionList);
    return;
  }
#endif
  completionHandler(UNNotificationPresentationOptionAlert);

}

- (void)userNotificationCenter:(UNUserNotificationCenter*)center
didReceiveNotificationResponse:(UNNotificationResponse*)response
         withCompletionHandler:(void (^)(void))completionHandler {
  NSString* actionId = response.actionIdentifier;
  NSDictionary* ui = response.notification.request.content.userInfo;
  NSString* type = [ui[@"type"] isKindOfClass:[NSString class]] ? ui[@"type"] : @"sport_running";
  NSString* payload = [ui[@"payload"] isKindOfClass:[NSString class]] ? ui[@"payload"] : nil;

  if ([actionId isEqualToString:@"SPORT_PAUSE"]) {
    [self _sportStop];
  } else if ([actionId isEqualToString:@"SPORT_RESUME"]) {
    int rid = _sportRecordId;
    if (rid <= 0 && [payload isKindOfClass:[NSString class]]) {
      NSScanner* sc = [NSScanner scannerWithString:payload];
      [sc scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL];
      [sc scanInt:&rid];
    }
    if (rid > 0) {
      [self _sportStart:rid];
    }
  } else if ([actionId isEqualToString:UNNotificationDefaultActionIdentifier]) {
    NSDictionary* args = @{ @"type": type, @"payload": payload ?: @"{}" };
    // Save as pending first (cold start), then try emit.
    [self _savePendingNotifTap:args];
    [self _emitNotifTapToFlutterIfPossible:args];
  }

  if (completionHandler) completionHandler();
}
#if 0  // Disabled duplicate sport native implementation kept for reference
#pragma mark - Sport Native Tracking (iOS)


// Pending notification tap delivery to Flutter (cold start safety)
- (NSString*)_pendingNotifKey {
  return @"quoteapp_pending_notif_tap";
}

- (void)_savePendingNotifTap:(NSDictionary*)args {
  if (args == nil) return;
  [[NSUserDefaults standardUserDefaults] setObject:args forKey:[self _pendingNotifKey]];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary*)_loadPendingNotifTap {
  id v = [[NSUserDefaults standardUserDefaults] objectForKey:[self _pendingNotifKey]];
  if (![v isKindOfClass:[NSDictionary class]]) return nil;
  return (NSDictionary*)v;
}

- (void)_clearPendingNotifTap {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self _pendingNotifKey]];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString*)_formatDuration:(int)sec {
  int s = MAX(0, sec);
  int h = s / 3600;
  int m = (s % 3600) / 60;
  int ss = s % 60;
  return [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, ss];
}

- (NSString*)_buildSportNotifLine:(NSDictionary*)snap {
  if (snap == nil) return @"";
  NSString* status = [snap[@"status"] isKindOfClass:[NSString class]] ? snap[@"status"] : @"in_progress";
  int dur = [snap[@"total_duration"] respondsToSelector:@selector(intValue)] ? [snap[@"total_duration"] intValue] : 0;
  double distM = [snap[@"total_distance"] respondsToSelector:@selector(doubleValue)] ? [snap[@"total_distance"] doubleValue] : 0.0;
  int steps = [snap[@"total_steps"] respondsToSelector:@selector(intValue)] ? [snap[@"total_steps"] intValue] : 0;

  NSString* prefix = [status isEqualToString:@"paused"] ? @"已暂停 · " : @"";
  NSString* timeStr = [self _formatDuration:dur];

  // A原则：有目标就显示进度/目标，无目标显示距离+时间
  if (_sportTargetType != nil && _sportTargetType.length > 0 && _sportTargetValue > 0.0) {
    if ([_sportTargetType isEqualToString:@"steps"]) {
      int tv = (int)llround(_sportTargetValue);
      NSString* unit = (_sportTargetUnit != nil && _sportTargetUnit.length > 0) ? _sportTargetUnit : @"步";
      if (tv > 0) {
        return [NSString stringWithFormat:@"%@%d / %d %@ · %@", prefix, steps, tv, unit, timeStr];
      }
    } else if ([_sportTargetType isEqualToString:@"distance"]) {
      double km = distM / 1000.0;
      NSString* unit = (_sportTargetUnit != nil && _sportTargetUnit.length > 0) ? _sportTargetUnit : @"km";
      return [NSString stringWithFormat:@"%@%.2f %@ / %.2f %@ · %@", prefix, km, unit, _sportTargetValue, unit, timeStr];
    } else if ([_sportTargetType isEqualToString:@"duration"]) {
      // targetValue uses hours (from plan edit)
      int targetSec = (int)MAX(0, llround(_sportTargetValue * 3600.0));
      if (targetSec > 0) {
        return [NSString stringWithFormat:@"%@%@ / %@", prefix, [self _formatDuration:dur], [self _formatDuration:targetSec]];
      }
    }
  }

  double km = distM / 1000.0;
  return [NSString stringWithFormat:@"%@%.2f km · %@", prefix, km, timeStr];
}

- (NSString*)_sportNotifIdentifier {
  if (_sportRecordId <= 0) return @"quoteapp_sport_running_0";
  return [NSString stringWithFormat:@"quoteapp_sport_running_%d", _sportRecordId];
}

- (void)_setupSportNotificationCategories {
  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
  center.delegate = self;

  UNNotificationAction* pauseAction =
      [UNNotificationAction actionWithIdentifier:@"SPORT_PAUSE" title:@"暂停" options:UNNotificationActionOptionNone];
  UNNotificationAction* resumeAction =
      [UNNotificationAction actionWithIdentifier:@"SPORT_RESUME" title:@"继续" options:UNNotificationActionOptionNone];

  UNNotificationCategory* catActive =
      [UNNotificationCategory categoryWithIdentifier:@"SPORT_RUNNING_ACTIVE"
                                           actions:@[ pauseAction ]
                                 intentIdentifiers:@[]
                                           options:UNNotificationCategoryOptionCustomDismissAction];

  UNNotificationCategory* catPaused =
      [UNNotificationCategory categoryWithIdentifier:@"SPORT_RUNNING_PAUSED"
                                           actions:@[ resumeAction ]
                                 intentIdentifiers:@[]
                                           options:UNNotificationCategoryOptionCustomDismissAction];

  NSSet* cats = [NSSet setWithObjects:catActive, catPaused, nil];
  [center setNotificationCategories:cats];
}

- (void)_updateSportLocalNotification {
  if (_sportRecordId <= 0) return;

  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];

  NSDictionary* snap = [self _sportSnapshot];
  NSString* status = [snap[@"status"] isKindOfClass:[NSString class]] ? snap[@"status"] : @"in_progress";
  NSString* line = [self _buildSportNotifLine:snap];
  if (line == nil) line = @"";

  // throttle updates to avoid spamming
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  if (_lastNotifUpdateTs > 0 && (now - _lastNotifUpdateTs) < 10.0) {
    return;
  }
  _lastNotifUpdateTs = now;

  UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
  content.title = (_sportTitle != nil && _sportTitle.length > 0) ? _sportTitle : @"运动进行中";
  content.body = line;
  content.sound = nil;
  content.threadIdentifier = @"quoteapp_sport_running";
  content.categoryIdentifier = [status isEqualToString:@"paused"] ? @"SPORT_RUNNING_PAUSED" : @"SPORT_RUNNING_ACTIVE";
  content.userInfo = @{
    @"type": @"sport_running",
    @"payload": [NSString stringWithFormat:@"{\"recordId\":%d}", _sportRecordId],
  };

  if (@available(iOS 15.0, *)) {
    content.interruptionLevel = UNNotificationInterruptionLevelPassive;
  }

  NSString* ident = [self _sportNotifIdentifier];

  // Keep only one notification visible by removing previous then adding.
  [center removeDeliveredNotificationsWithIdentifiers:@[ ident ]];
  [center removePendingNotificationRequestsWithIdentifiers:@[ ident ]];

  UNNotificationRequest* req = [UNNotificationRequest requestWithIdentifier:ident content:content trigger:nil];
  [center addNotificationRequest:req withCompletionHandler:^(NSError* _Nullable error) {
    // ignore
  }];
}

- (void)_removeSportLocalNotification {
  UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
  NSString* ident = [self _sportNotifIdentifier];
  [center removeDeliveredNotificationsWithIdentifiers:@[ ident ]];
  [center removePendingNotificationRequestsWithIdentifiers:@[ ident ]];
}

- (void)_emitNotifTapToFlutterIfPossible:(NSDictionary*)args {
  if (args == nil) return;
  if (_sysChannel != nil) {
    [_sysChannel invokeMethod:@"onNativeNotificationTap" arguments:args];
  } else {
    [self _savePendingNotifTap:args];
  }
}

- (void)_emitPendingNotifTapIfAny {
  NSDictionary* pending = [self _loadPendingNotifTap];
  if (pending == nil) return;
  [self _clearPendingNotifTap];
  if (_sysChannel != nil) {
    [_sysChannel invokeMethod:@"onNativeNotificationTap" arguments:pending];
  }
}


- (NSString*)_sportSnapshotKey:(int)recordId {
  return [NSString stringWithFormat:@"quoteapp_sport_fg_%d", recordId];
}

- (NSDictionary*)_loadSportSnapshot:(int)recordId {
  NSString* key = [self _sportSnapshotKey:recordId];
  NSDictionary* d = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (![d isKindOfClass:[NSDictionary class]]) return nil;
  return d;
}

- (void)_saveSportSnapshot:(NSDictionary*)snapshot recordId:(int)recordId {
  NSString* key = [self _sportSnapshotKey:recordId];
  [[NSUserDefaults standardUserDefaults] setObject:snapshot forKey:key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (int)_currentDurationSec {
  if (!_sportRunning) return _baseDurationSec;
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  int inc = (int)MAX(0, floor(now - _startTs));
  return _baseDurationSec + inc;
}

- (NSDictionary*)_sportSnapshot {
  int dur = [self _currentDurationSec];
  double dist = _baseDistanceM + _sessionDistanceM;
  int steps = _baseSteps + (int)llround(_sessionDistanceM / 0.75); // rough step length
  double avg = (dur > 0) ? (dist / (double)dur) * 3.6 : 0.0;
  return @{
    @"status": (_sportRunning ? @"in_progress" : @"paused"),
    @"total_duration": @(dur),
    @"total_distance": @(dist),
    @"total_steps": @(steps),
    @"current_speed": @(_currentSpeedKmh),
    @"avg_speed": @(avg),
  };
}

- (BOOL)_sportIsRunning {
  return _sportRunning;
}

- (void)_sportStart:(int)recordId {
  if (recordId <= 0) return;

  // Load previous snapshot as base (so leaving page / relaunch won't lose data).
  NSDictionary* snap = [self _loadSportSnapshot:recordId];
  _baseDurationSec = [snap[@"total_duration"] respondsToSelector:@selector(intValue)] ? [snap[@"total_duration"] intValue] : 0;
  _baseDistanceM = [snap[@"total_distance"] respondsToSelector:@selector(doubleValue)] ? [snap[@"total_distance"] doubleValue] : 0.0;
  _baseSteps = [snap[@"total_steps"] respondsToSelector:@selector(intValue)] ? [snap[@"total_steps"] intValue] : 0;

  _sportRecordId = recordId;
  _sessionDistanceM = 0.0;
  _currentSpeedKmh = 0.0;
  _lastLoc = nil;
  _lastLocTs = 0;
  _startTs = [[NSDate date] timeIntervalSince1970];
  _sportRunning = YES;

  if (_locMgr == nil) {
    _locMgr = [[CLLocationManager alloc] init];
    _locMgr.delegate = self;
    _locMgr.desiredAccuracy = kCLLocationAccuracyBest;
    _locMgr.distanceFilter = 1.0;
    _locMgr.pausesLocationUpdatesAutomatically = NO;
    if ([_locMgr respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)]) {
      _locMgr.allowsBackgroundLocationUpdates = YES;
    }
  }

  // Try request authorization. (User still needs to grant in Settings.)
  if ([_locMgr respondsToSelector:@selector(requestAlwaysAuthorization)]) {
    [_locMgr requestAlwaysAuthorization];
  } else if ([_locMgr respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
    [_locMgr requestWhenInUseAuthorization];
  }

  [_locMgr startUpdatingLocation];

  [_sportTimer invalidate];
  _sportTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                 target:self
                                               selector:@selector(_sportTick)
                                               userInfo:nil
                                                repeats:YES];

  // Persist immediately.
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId];
}

- (void)_sportStop {
  _sportRunning = NO;
  if (_locMgr != nil) {
    [_locMgr stopUpdatingLocation];
  }
  [_sportTimer invalidate];
  _sportTimer = nil;

  // Persist paused snapshot.
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId];
}

- (void)_sportTick {
  if (!_sportRunning) return;
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray<CLLocation*>*)locations {
  if (!_sportRunning || locations.count == 0) return;
  CLLocation* loc = [locations lastObject];

  // Ignore poor accuracy fixes.
  if (loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 80) return;

  NSTimeInterval ts = [loc.timestamp timeIntervalSince1970];
  if (_lastLoc != nil) {
    double d = [loc distanceFromLocation:_lastLoc];
    if (d >= 0 && d < 2000) {
      _sessionDistanceM += d;
      double dt = ts - _lastLocTs;
      if (loc.speed >= 0) {
        _currentSpeedKmh = loc.speed * 3.6;
      } else if (dt > 0.2) {
        _currentSpeedKmh = (d / dt) * 3.6;
      }
    }
  }

  _lastLoc = loc;
  _lastLocTs = ts;

  // Persist after each location update as well.
  NSDictionary* out = [self _sportSnapshot];
  [self _saveSportSnapshot:out recordId:_sportRecordId];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    willPresentNotification:(UNNotification *)notification
      withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {// Avoid noisy banners; keep it in notification center list when foreground.
if (@available(iOS 14.0, *)) {
  completionHandler(UNNotificationPresentationOptionList);
} else {
  completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
  NSString* actionId = response.actionIdentifier;
  NSDictionary* ui = response.notification.request.content.userInfo;
  NSString* type = [ui[@"type"] isKindOfClass:[NSString class]] ? ui[@"type"] : nil;
  NSString* payload = [ui[@"payload"] isKindOfClass:[NSString class]] ? ui[@"payload"] : nil;
  if (type == nil) type = @"sport_running";
  if (payload == nil && _sportRecordId > 0) {
    payload = [NSString stringWithFormat:@"{\"recordId\":%d}", _sportRecordId];
  }

  if ([actionId isEqualToString:@"SPORT_PAUSE"]) {
    // Pause from notification
    [self _sportStop];
    [self _updateSportLocalNotification];
  } else if ([actionId isEqualToString:@"SPORT_RESUME"]) {
    // Resume from notification
    int rid = _sportRecordId;
    if (rid <= 0) {
      // try extract from payload
      rid = _sportRecordId;
    }
    if (rid > 0) {
      [self _sportStart:rid];
      [self _updateSportLocalNotification];
    }
  } else if ([actionId isEqualToString:UNNotificationDefaultActionIdentifier]) {
    NSDictionary* args = @{ @"type": type, @"payload": payload ?: @"{}" };
    // Save as pending first (cold start), then try emit.
    [self _savePendingNotifTap:args];
    [self _emitNotifTapToFlutterIfPossible:args];
  } else {
    // dismiss / other
  }

  if (completionHandler) completionHandler();
}

#endif
@end
