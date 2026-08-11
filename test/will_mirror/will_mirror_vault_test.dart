import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:quote_app/will_mirror/will_mirror_vault.dart';
import 'package:quote_app/will_mirror/will_mirror_vault_cipher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late _TestCipher cipher;
  late WillMirrorVault vault;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('will_mirror_vault_');
    cipher = _TestCipher();
    vault = WillMirrorVault(
      cipher: cipher,
      factory: databaseFactoryFfi,
      baseDirectoryProvider: () async => directory.path,
    );
  });

  tearDown(() async {
    await vault.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('private evidence round-trips while plaintext never reaches SQLite',
      () async {
    const secret = 'WM-SECRET-这段私密人生叙述绝不能出现在数据库明文中';
    const now = 1000;
    const goal = WillMirrorGoal(
      id: 'goal-1',
      text: secret,
      domain: '工作与自主',
      baselineDesire: 78,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    await vault.saveGoal(goal);
    await vault.saveWhyNode(const WillMirrorWhyNode(
      id: 'why-1',
      goalId: 'goal-1',
      parentId: null,
      nodeType: 'surface',
      text: '为了按自己的节奏生活',
      depth: 0,
      createdAt: now,
    ));
    await vault.saveProbe(const WillMirrorProbe(
      id: 'probe-1',
      goalId: 'goal-1',
      nodeId: 'why-1',
      type: WillMirrorProbeType.noAudience,
      baseline: 78,
      after: 70,
      answer: '无人知道时仍然想要',
      createdAt: now,
    ));
    await vault.saveEvidence(const WillMirrorLifeEvidence(
      id: 'evidence-1',
      goalId: 'goal-1',
      type: WillMirrorEvidenceType.action,
      title: '主动争取自主项目',
      note: '没有观众也持续了半年',
      lifeStage: '工作后',
      domain: '工作',
      intensity: 8,
      duration: 5,
      costLevel: 7,
      audiencePresent: false,
      externallyRequested: false,
      rewardPresent: false,
      energyBefore: 4,
      energyAfter: 8,
      repeatWish: 9,
      occurredAt: now,
      createdAt: now,
    ));
    await vault.saveHypothesis(const WillMirrorHypothesis(
      id: 'hypothesis-1',
      goalId: 'goal-1',
      label: '自主',
      type: WillMirrorHypothesisType.stableWant,
      status: 'candidate',
      confidenceBand: WillMirrorConfidenceBand.medium,
      explanation: '跨情境重复，但还需反证',
      counterSearchCompleted: true,
      counterSearchNote: '已检查照护责任情境',
      createdAt: now,
      updatedAt: now,
    ));
    await vault.linkEvidence(const WillMirrorHypothesisEvidence(
      hypothesisId: 'hypothesis-1',
      evidenceId: 'evidence-1',
      relation: WillMirrorRelation.supports,
      weight: 0.8,
      contextLimit: '在低风险工作选择中',
    ));
    await vault.saveExperiment(const WillMirrorExperiment(
      id: 'experiment-1',
      hypothesisId: 'hypothesis-1',
      title: '七日自主节奏实验',
      protocol: '每天自行安排一小时，并记录能量与持续性',
      startAt: now,
      endAt: now + 7 * 24 * 60 * 60 * 1000,
      status: WillMirrorExperimentStatus.active,
      createdAt: now,
    ));
    await vault.saveObservation(const WillMirrorObservation(
      id: 'observation-1',
      experimentId: 'experiment-1',
      energy: 8,
      realMe: 9,
      persistence: 8,
      satisfaction: 7,
      note: '没有奖励也愿意继续',
      observedAt: now,
    ));

    const updatedSecret = '$secret · 已更新';
    await vault.saveGoal(goal.copyWith(
      text: updatedSecret,
      updatedAt: now + 1,
    ));
    final hypothesis = (await vault.hypotheses('goal-1')).single;
    await vault.saveHypothesis(hypothesis.copyWith(
      explanation: '更新后的暂定模型',
      updatedAt: now + 1,
    ));
    final experiment = (await vault.experiments()).single;
    await vault.saveExperiment(
      experiment.copyWith(status: WillMirrorExperimentStatus.completed),
    );

    expect((await vault.activeGoal())?.text, updatedSecret);
    expect(await vault.whyNodes('goal-1'), hasLength(1));
    expect(await vault.probes('goal-1'), hasLength(1));
    expect((await vault.evidenceForGoal('goal-1')).single.title, '主动争取自主项目');
    expect((await vault.hypotheses('goal-1')).single.label, '自主');
    expect(
      (await vault.links('hypothesis-1')).single.contextLimit,
      '在低风险工作选择中',
      reason: '更新候选不能级联删除证据关联',
    );
    expect((await vault.experiments()).single.title, '七日自主节奏实验');
    expect(
      (await vault.observations('experiment-1')).single.note,
      '没有奖励也愿意继续',
      reason: '更新实验状态不能级联删除观察记录',
    );

    final exported = await vault.exportDecrypted();
    expect(jsonEncode(exported), contains(updatedSecret));
    expect(exported['notice'], contains('明文副本'));

    await vault.close();
    final databasePath = p.join(directory.path, WillMirrorVault.fileName);
    final databaseBytes = await File(databasePath).readAsBytes();
    final rawDatabase = String.fromCharCodes(databaseBytes);
    expect(rawDatabase, isNot(contains(secret)));
    expect(rawDatabase, isNot(contains(updatedSecret)));
    expect(rawDatabase, isNot(contains('主动争取自主项目')));

    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    final outboxCount = Sqflite.firstIntValue(
      await raw.rawQuery('SELECT COUNT(*) FROM wm_sync_outbox'),
    );
    await raw.close();
    expect(outboxCount, 0, reason: '同步默认必须关闭');
  });

  test('deleteAll removes database and destroys the encryption key', () async {
    await vault.saveGoal(const WillMirrorGoal(
      id: 'goal-delete',
      text: '删除我',
      domain: '测试',
      baselineDesire: 50,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    ));
    final databasePath = p.join(directory.path, WillMirrorVault.fileName);
    expect(await File(databasePath).exists(), isTrue);

    await vault.deleteAll();

    expect(await File(databasePath).exists(), isFalse);
    expect(cipher.destroyed, isTrue);
  });
}

class _TestCipher implements WillMirrorVaultCipher {
  bool destroyed = false;

  @override
  Future<bool> isAvailable() async => !destroyed;

  @override
  Future<String> encrypt(String plaintext) async {
    if (destroyed) throw StateError('test key destroyed');
    final encoded = base64Encode(utf8.encode(plaintext));
    return 'wm1:${encoded.split('').reversed.join()}';
  }

  @override
  Future<String> decrypt(String ciphertext) async {
    if (destroyed) throw StateError('test key destroyed');
    if (!ciphertext.startsWith('wm1:')) throw const FormatException('cipher');
    final reversed = ciphertext.substring(4).split('').reversed.join();
    return utf8.decode(base64Decode(reversed));
  }

  @override
  Future<void> destroyKey() async {
    destroyed = true;
  }
}
