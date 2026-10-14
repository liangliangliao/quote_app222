import '../application/controller.dart';
import '../data/store.dart';
import 'private_model.dart';
import 'reminders.dart';

/// Notification entry and discovery share one live ledger and invalidations.
class MirrorRuntime {
  static Future<MirrorController>? _instance;
  static int _readers = 0;
  static Future<MirrorController> acquire() async {
    _readers++;
    final task = _instance ??= _create();
    try {
      return await task;
    } catch (_) {
      _readers--;
      if (identical(_instance, task)) _instance = null;
      rethrow;
    }
  }

  static Future<MirrorController> _create() async {
    final store = await SqliteMirrorStore.open();
    final controller = MirrorController(
        store: store,
        model: HostPrivateModel(),
        reminders: AndroidMirrorReminders());
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      controller.dispose();
      await store.close();
      rethrow;
    }
  }

  static Future<void> release(MirrorController controller) async {
    _readers--;
    if (_readers == 0) {
      _instance = null;
      controller.dispose();
      await controller.store.close();
    }
  }
}
