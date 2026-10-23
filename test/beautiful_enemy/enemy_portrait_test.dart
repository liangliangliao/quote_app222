import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/copy.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/persona.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_oracle.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_talker.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_persona_prompt.dart';

void main() {
  group('美丽的敌人：双重特征与七项职责', () {
    test('AI 的判词和对话共享相同人格核心', () {
      const String core = EnemyPersonaPrompt.core;
      expect(core, contains('美丽 Beautiful'));
      expect(core, contains('敌人 Enemy'));
      for (final String duty in <String>[
        '事实监督', '认知挑战', '成长推动', '动机唤醒',
        '行动督促', '反馈复盘', '支持守护',
      ]) {
        expect(core, contains(duty), reason: duty);
      }
      expect(core, contains('数据缺失≠他没做'));
      expect(core, contains('用户自主选择'));
      expect(EnemyAiOracle.systemPrompt, contains(core));
      expect(EnemyAiTalker.systemPrompt, contains(core));
    });

    test('对话强度不允许改写尊重与同意边界', () {
      expect(EnemyAiTalker.systemPrompt, contains('均不得粗口'));
      expect(EnemyAiOracle.systemPrompt, contains('任何档位都不准粗口'));
      const DraftValidator validator = DraftValidator();
      expect(validator.validateLine('少他妈废话', maxTone: 3),
          contains('profanity_not_allowed'));
    });

    test('本地展示能解释角色职责和自主权', () {
      expect(EnemyCopy.portraitBeautiful, contains('尊重人格'));
      expect(EnemyCopy.portraitEnemy, contains('坚持事实'));
      expect(EnemyCopy.portraitMission, contains('支持守护'));
      expect(EnemyCopy.portraitBoundary, contains('可以申辩'));
    });

    test('成功时认可可验证的进步，而不是自动加压', () {
      final String answer = EnemyCopy.acknowledgement('完成了代码练习', 3);
      expect(answer, contains('有记录的进步'));
      expect(answer, isNot(contains('门槛抬高')));
      final String local = PersonaLines.interject(
        type: 'habit_done', label: '晨跑', address: '对手', tone: 3, seed: 2,
      );
      expect(local, contains('做到了'));
      expect(local, contains('由你选择'));
    });

    test('数据缺失与用户拒绝不能被当作失败或默许', () {
      expect(EnemyCopy.insufficient, contains('不等于你没有行动'));
      final String line = PersonaLines.claimNoRecord('对手');
      expect(line, contains('暂未找到'));
      expect(line, isNot(contains('你没做')));
      final String reject = PersonaLines.rebut(
        address: '对手', reason: '目前身体不舒服', seed: 1,
      );
      expect(reject, contains('动议已驳回'));
      expect(reject, isNot(contains('动议不撤')));
    });
  });
}
