import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_knowledge_repository.dart';
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late WillMirrorKnowledgeRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('will_mirror_kb_test_');
    repository = WillMirrorKnowledgeRepository(
      factory: databaseFactoryFfi,
      baseDirectoryProvider: () async => directory.path,
      assetLoader: rootBundle.loadString,
    );
  });

  tearDown(() async {
    await repository.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('manifest hash compiles exactly 22 evidence records', () async {
    final manifest = await repository.manifest();
    final records = await repository.allPassages();

    expect(manifest.kbVersion, '4.0.0-kb.1');
    expect(manifest.recordCount, 22);
    expect(manifest.recordsSha256, hasLength(64));
    expect(records, hasLength(22));
    expect(
      WillMirrorKnowledgeRepository.validateRecords(records),
      isEmpty,
    );
    expect(
      records.where(
        (record) => record.evidenceLevel == WillMirrorEvidenceLevel.a,
      ),
      hasLength(13),
    );
    expect(
      records.where(
        (record) =>
            record.evidenceLevel == WillMirrorEvidenceLevel.aCandidate,
      ),
      hasLength(5),
    );
  });

  test('source, translation, product rule and misuse boundary stay separate',
      () async {
    final records = await repository.allPassages();
    for (final record in records) {
      expect(record.originalText, isNotEmpty, reason: record.recordId);
      expect(record.zhTranslation, isNotEmpty, reason: record.recordId);
      expect(record.summary, isNotEmpty, reason: record.recordId);
      expect(record.misuseBoundary, isNotEmpty, reason: record.recordId);
      expect(
        record.originalText,
        isNot(record.zhTranslation),
        reason: record.recordId,
      );
    }
    expect(
      records
          .where((record) => record.evidenceLevel == WillMirrorEvidenceLevel.c)
          .every((record) => record.productRule.isNotEmpty),
      isTrue,
    );
  });

  test('compiled database passes integrity and triple retrieval', () async {
    final validation = await repository.validateCompiledDatabase();
    final bundle = await repository.retrieveForHypothesis('自主与自我一致');

    expect(validation.valid, isTrue);
    expect(validation.integrityCheck.toLowerCase(), 'ok');
    expect(bundle.support, isNotEmpty);
    expect(bundle.counter, isNotEmpty);
    expect(bundle.boundary, isNotEmpty);
    expect(
      bundle.counter.every(
        (record) => record.relations.any(
          (relation) =>
              relation == WillMirrorRelation.limits ||
              relation == WillMirrorRelation.contradicts,
        ),
      ),
      isTrue,
    );
  });
}
