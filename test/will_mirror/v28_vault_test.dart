import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:quote_app/will_mirror/will_mirror_vault.dart';
import 'package:quote_app/will_mirror/will_mirror_vault_cipher.dart';
import 'package:quote_app/will_mirror/v28/case_models.dart';
import 'package:quote_app/will_mirror/v28/case_workflow.dart';

class _Cipher implements WillMirrorVaultCipher {
  bool destroyed = false;
  @override
  Future<bool> isAvailable() async => !destroyed;
  @override
  Future<String> encrypt(String value) async =>
      'test:${base64Encode(utf8.encode(value))}';
  @override
  Future<String> decrypt(String value) async =>
      utf8.decode(base64Decode(value.substring(5)));
  @override
  Future<void> destroyKey() async {
    destroyed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late WillMirrorVault vault;
  late _Cipher cipher;
  late WmWorkflow flow;
  WillMirrorVault open() => WillMirrorVault(
      cipher: cipher,
      factory: databaseFactoryFfi,
      baseDirectoryProvider: () async => directory.path);
  Future<WmCase> create(String id, String text) async {
    final c = flow.start(id, text);
    await vault.saveGoal(WillMirrorGoal(
        id: id,
        text: text,
        domain: '测试',
        baselineDesire: 0,
        status: 'case_open',
        createdAt: c.createdAt,
        updatedAt: c.updatedAt));
    return vault.saveCaseFile(c);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wm_v28_');
    cipher = _Cipher();
    flow = WmWorkflow();
    vault = open();
  });
  tearDown(() async {
    await vault.close();
    await directory.delete(recursive: true);
  });

  test(
      'v1 database migrates in place without deleting goals or changing their ID',
      () async {
    final before = await create('existing_goal', '既有目标');
    await vault.writeSetting('v5_preserved', '保留原有设置');
    await vault.close();
    final db = await databaseFactoryFfi
        .openDatabase(p.join(directory.path, WillMirrorVault.fileName));
    await db.execute('DROP TABLE wm_case_state');
    await db.setVersion(1);
    await db.close();
    vault = open();
    expect((await vault.goals()).single.id, before.id);
    expect(await vault.readSetting('v5_preserved'), '保留原有设置');
    expect(await vault.caseFile(before.id), isNull);
    final migrated = await vault.saveCaseFile(flow.start(before.id, '既有目标'));
    expect(migrated.id, before.id);
    expect(await vault.goals(), hasLength(1));
    expect(await vault.caseFiles(), hasLength(1));
    await vault.close();
    final check = await databaseFactoryFfi
        .openDatabase(p.join(directory.path, WillMirrorVault.fileName));
    expect(await check.getVersion(), 2);
    await check.close();
  });

  test(
      'aggregate round-trips encrypted; no narrative or proxy token in raw SQLite',
      () async {
    const secret = 'WM_PRIVATE_一段只属于本人的经历_2026';
    var c = await create('private_case', secret);
    c = await vault
        .saveCaseFile(flow.recordAction(c, kind: 'preparation', text: secret));
    await vault.writeSetting(
        'v28_decisions_session', 'SERVICE_TOKEN_PRIVATE_123456789');
    await vault.close();
    final raw = await File(p.join(directory.path, WillMirrorVault.fileName))
        .readAsBytes();
    bool containsBytes(List<int> query) {
      for (var i = 0; i <= raw.length - query.length; i++) {
        if (List.generate(query.length, (j) => raw[i + j] == query[j])
            .every((v) => v)) return true;
      }
      return false;
    }

    expect(containsBytes(utf8.encode(secret)), isFalse);
    expect(
        containsBytes(utf8.encode('SERVICE_TOKEN_PRIVATE_123456789')), isFalse);
    vault = open();
    expect((await vault.caseFile(c.id))!.evidence.last.text, secret);
    final exported = jsonEncode(await vault.exportDecrypted());
    expect(exported, contains('case_v28'));
    expect(exported, contains(secret));
    expect(exported, isNot(contains('SERVICE_TOKEN_PRIVATE_123456789')));
  });

  test(
      'optimistic locking and immutable past reject stale or rewritten AI results',
      () async {
    var c = await create('a', '同一课题');
    final stale = c;
    c = await vault.saveCaseFile(
        flow.seal(c, trigger: '真实条件出现', ifThen: '做一步', fallback: '暂停'));
    expect(() => vault.saveCaseFile(stale), throwsStateError);
    final forged = c.change({
      'snapshots': [
        {
          ...c.snapshots.single,
          'payload': {'prediction': '我早就知道'}
        }
      ]
    });
    expect(() => vault.saveCaseFile(forged), throwsStateError);
    final evidenceRewrite = c.change({
      'evidence': [
        {...c.evidence.first.toJson(), 'text': '事后重写原话'}
      ]
    });
    expect(() => vault.saveCaseFile(evidenceRewrite), throwsStateError);
    expect(
        WmWorkflow.verifySeal((await vault.caseFile(c.id))!.snapshots.single),
        isTrue);
  });

  test(
      'principle revisions and withdrawal propagate atomically across case references',
      () async {
    var source = await create('source', '来源课题');
    source = flow.recordAction(source,
        kind: 'attempt', text: 'WM_REVOKED_已经实际试过先列资料');
    final eid = source.evidence.last.id;
    source = flow.principle(source,
        summary: '先列资料或许有帮助',
        condition: '非紧急的资料任务',
        action: '先列出需要的资料',
        exception: '危险时停止',
        evidenceIds: [eid],
        nextTest: '下一轮检查');
    source = await vault.saveCaseFile(flow.principleStatus(
        source, source.latestPrinciples.single, WmPrincipleStatus.accepted));
    var target = await create('target', '新的相关课题');
    target = flow.applyPrinciple(
        target.change({
          'allowedSourceCaseIds': [source.id]
        }),
        source,
        source.latestPrinciples.single,
        contextMatches: true);
    target = await vault.saveCaseFile(
        flow.seal(target, trigger: '资料可用', ifThen: '列清单', fallback: '暂停'));
    final oldSeal = jsonEncode(target.snapshots.single['payload']);
    source = await vault.saveCaseFile(flow.principleStatus(
        source, source.latestPrinciples.single, WmPrincipleStatus.needsReview));
    target = (await vault.caseFile(target.id))!;
    expect(target.principleUses.single['status'], 'stale_source_revision');
    expect(jsonEncode(target.snapshots.single['payload']), oldSeal);
    await vault.revokeCaseEvidence(source.id, eid);
    final withdrawn = (await vault.caseFile(source.id))!;
    target = (await vault.caseFile(target.id))!;
    expect(withdrawn.latestPrinciples.single.status, WmPrincipleStatus.revoked);
    expect(target.allowedSourceCaseIds, isEmpty);
    expect(target.principleUses.single['status'], 'stale_due_to_revocation');
    expect(jsonEncode(await vault.exportDecrypted()),
        isNot(contains('WM_REVOKED_')));
    expect(() => vault.saveCaseFile(source), throwsStateError);
    await vault.deleteCaseFile(source.id);
    expect(await vault.caseFile(source.id), isNull);
    expect(await vault.caseFile(target.id), isNotNull);
  });

  test('deleteAll destroys the same Vault key and removes the case database',
      () async {
    await create('erase', '待删除');
    await vault.deleteAll();
    expect(cipher.destroyed, isTrue);
    expect(
        await File(p.join(directory.path, WillMirrorVault.fileName)).exists(),
        isFalse);
  });
}
