import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'package:quote_app/self_os/self_os_experience_entry.dart';
import 'package:quote_app/self_os/self_os_experience_page.dart';
import 'package:quote_app/self_os/self_os_experience_reminders.dart';
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_principles_test.dart' show experienceSource, principleFor;
import 'self_os_widget_test.dart' show MemoryRepository;

void main() {
  test('T364 payload严格保留caseId+principleId+triggerId，不包含个人文本', () {
    const link = OsPrincipleLink('案例1', 'p-1', 'trigger-1');
    final parsed = OsPrincipleLink.parse(link.encode())!;
    expect(parsed.caseId, '案例1');
    expect(parsed.principleId, 'p-1');
    expect(parsed.triggerId, 'trigger-1');
    expect(OsPrincipleLink.parse('other:payload'), isNull);
    expect(OsPrincipleLink.parse('${OsPrincipleLink.prefix}invalid'), isNull);
    expect(OsPrincipleLink.parse(const OsPrincipleLink('c', 'p', '').encode()),
        isNull);
    expect(SelfOsExperienceReminders.idFor('a'),
        SelfOsExperienceReminders.idFor('a'));
    expect(SelfOsExperienceReminders.idFor('a'),
        isNot(SelfOsExperienceReminders.idFor('b')));
  });

  for (final invalid in [false, true]) {
    testWidgets('T364 精确打开目标应用，错配trigger不回退到其他案例：$invalid', (tester) async {
      final source = experienceSource(),
          c = plannedCase(),
          other = plannedCase();
      final p = principleFor([source]), repo = MemoryRepository();
      repo.profile.experienceSettings['remindersEnabled'] = true;
      repo.profile.principles.add(p);
      final a = SelfOsPrinciples.choose(c, p, [source, c],
          contextMatches: true, safe: true);
      final b = SelfOsPrinciples.choose(other, p, [source, other],
          contextMatches: true, safe: true);
      for (final entry in [source, c, other]) {
        repo.records[entry.id] = entry;
      }
      await tester.pumpWidget(MaterialApp(
          home: SelfOsExperienceEntry(
              repository: repo,
              link: OsPrincipleLink(
                  c.id, p['id'], invalid ? b['triggerId'] : a['triggerId']))));
      await tester.pumpAndSettle();
      if (invalid) {
        expect(find.byType(SelfOsExperiencePage), findsNothing);
        expect(find.textContaining('提示目前不可用'), findsOneWidget);
      } else {
        final page = tester
            .widget<SelfOsExperiencePage>(find.byType(SelfOsExperiencePage));
        expect(page.value.id, c.id);
        expect(page.initialApplicationId, a['id']);
        final saved = SelfOsPrinciples.applications(repo.records[c.id]!).single;
        expect(saved['exposureStatus'], 'opened');
        expect(saved['recallStatus'], 'unknown');
        expect(saved['applicationStatus'], 'unknown');
        expect(saved['atT1'], isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('T339 已撤回或拒绝原则的旧通知不能打开旧内容', (tester) async {
    final source = experienceSource(),
        c = plannedCase(),
        repo = MemoryRepository();
    final p = principleFor([source]);
    repo.profile.experienceSettings['remindersEnabled'] = true;
    repo.profile.principles.add(p);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    p['status'] = 'user_rejected';
    repo.records.addAll({source.id: source, c.id: c});
    await tester.pumpWidget(MaterialApp(
        home: SelfOsExperienceEntry(
            repository: repo,
            link: OsPrincipleLink(c.id, p['id'], a['triggerId']))));
    await tester.pumpAndSettle();
    expect(find.byType(SelfOsExperiencePage), findsNothing);
    expect(
        SelfOsPrinciples.applications(repo.records[c.id]!)
            .single['exposureStatus'],
        'accepted');
  });
}
