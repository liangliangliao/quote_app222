import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Signals quote writes from either the UI isolate or a background task.
class QuoteChangeBus {
  static const portName = 'QUOTE_CHANGE_PORT';
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notifyWrite() {
    final port = ui.IsolateNameServer.lookupPortByName(portName);
    if (port != null) {
      port.send(null);
    } else {
      // Also works when a page is used independently, such as in a widget test.
      deliver();
    }
  }

  static void deliver() => changes.value++;
}
