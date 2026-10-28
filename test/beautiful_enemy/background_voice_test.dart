import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_voice_out.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late EnemyDao dao;
  final calls = <MethodCall>[];
  setUp(() async {
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    dao = EnemyDao(db);
    await dao.ensureSchema();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      calls.add(call);
      return 1;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await db.close();
  });
  test('后台播报等待语音完成，并在两种开关关闭时保持静默', () async {
    final voice = EnemyHostVoiceOut();
    await voice.speakWhileEnabled(dao, '请看看今天的行动');
    expect(calls, isEmpty);
    await dao.setBoolSetting(EnemySettings.voiceOut, true);
    await dao.setBoolSetting(EnemySettings.enabled, false);
    await voice.speakWhileEnabled(dao, '请看看今天的行动');
    expect(calls, isEmpty);
    await dao.setBoolSetting(EnemySettings.enabled, true);
    await voice.speakWhileEnabled(dao, '请看看今天的行动');
    expect(calls.any((c) => c.method == 'awaitSpeakCompletion' && c.arguments == true), isTrue);
    expect(calls.any((c) => c.method == 'speak' && c.arguments == '请看看今天的行动'), isTrue);
  });
}
