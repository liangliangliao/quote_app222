import 'meditation_models.dart';

class MeditationSeedData {
  static const List<String> stateOptions = [
    '心很乱',
    '被外界影响',
    '焦虑紧张',
    '疲惫无力',
    '想专注',
    '睡前放松',
    '日常练习',
    '被羞辱后反刍',
    '自责羞耻',
    '行动卡住',
    '身体紧绷',
    '需要定力',
    '价值感受挫',
  ];

  static const List<MeditationSessionTemplate> sessions = [
    MeditationSessionTemplate(
      key: 'breath_anchor_3m',
      title: '3分钟回到呼吸',
      type: '呼吸稳定',
      category: '新手入门',
      description: '用最短时间把注意力带回身体和呼吸。',
      durationSeconds: 180,
      steps: [
        MeditationStep(startSecond: 0, text: '现在，先不用解决任何问题。只是坐好，感受身体被支撑着。'),
        MeditationStep(startSecond: 20, text: '轻轻吸气，知道自己正在吸气。慢慢呼气，知道自己正在呼气。'),
        MeditationStep(startSecond: 45, text: '如果已经走神了，没有关系。看见走神，就是练习已经开始。'),
        MeditationStep(startSecond: 75, text: '把注意力放在鼻尖、胸口，或者腹部的起伏上。选择一个地方就够了。'),
        MeditationStep(startSecond: 110, text: '念头出现时，不需要赶走它。只是在心里说：我看见了，然后回来。'),
        MeditationStep(startSecond: 145, text: '最后几次呼吸，慢一点。让身体知道，此刻你正在回到自己。'),
      ],
      endingReflection: '你不是失败于分心，而是在每一次回来中训练自己。',
    ),
    MeditationSessionTemplate(
      key: 'rumination_stop_5m',
      title: '5分钟反刍中断',
      type: '反刍中断',
      category: '反刍中断',
      description: '当脑中反复争辩、回想、内耗时，先把注意力交还给自己。',
      durationSeconds: 300,
      steps: [
        MeditationStep(startSecond: 0, text: '先停一下。你不需要马上把那件事想明白。'),
        MeditationStep(startSecond: 25, text: '感受身体坐在这里。脚、腿、背部，都在此刻。'),
        MeditationStep(startSecond: 55, text: '如果脑中又开始播放那件事，只需要轻轻标记：这是反刍。'),
        MeditationStep(startSecond: 90, text: '我不需要继续和这个念头争辩。我先回到呼吸。'),
        MeditationStep(startSecond: 130, text: '吸气时，把注意力带回身体。呼气时，松开一点点紧绷。'),
        MeditationStep(startSecond: 175, text: '那件事可以暂时放在一边。现在最重要的是，把行动权交还给自己。'),
        MeditationStep(startSecond: 225, text: '如果又被带走，就再次回来。回来一次，就是一次训练。'),
        MeditationStep(startSecond: 270, text: '最后，感受一下：我在这里，我正在重新掌握自己的注意力。'),
      ],
      endingReflection: '你已经看见自己被念头带走，也正在把注意力交还给自己。',
    ),
    MeditationSessionTemplate(
      key: 'emotion_untangle_5m',
      title: '5分钟情绪脱钩',
      type: '情绪脱钩',
      category: '情绪脱钩',
      description: '愤怒、羞耻、焦虑出现时，练习感受它，但不立刻服从它。',
      durationSeconds: 300,
      steps: [
        MeditationStep(startSecond: 0, text: '把注意力放到身体里，看看情绪现在最明显的位置在哪里。'),
        MeditationStep(startSecond: 35, text: '也许在胸口、喉咙、腹部，或者肩膀。只需要观察。'),
        MeditationStep(startSecond: 70, text: '在心里说：情绪正在发生，但它不是我的全部。'),
        MeditationStep(startSecond: 110, text: '我可以感受到它，但不必立刻被它命令。'),
        MeditationStep(startSecond: 155, text: '每一次呼气，都给身体一点空间。不是压下情绪，而是给它空间。'),
        MeditationStep(startSecond: 205, text: '如果有故事出现，先回到身体感受：紧、热、酸、沉、快。'),
        MeditationStep(startSecond: 255, text: '最后，提醒自己：我可以带着情绪，仍然选择下一步行动。'),
      ],
      endingReflection: '情绪可以出现，但你不需要把整个人都交给情绪。',
    ),
    MeditationSessionTemplate(
      key: 'focus_return_5m',
      title: '5分钟专注回收',
      type: '专注回收',
      category: '专注回收',
      description: '学习或工作前，把散乱的注意力收回来。',
      durationSeconds: 300,
      steps: [
        MeditationStep(startSecond: 0, text: '先坐稳，放下手机或其他干扰。'),
        MeditationStep(startSecond: 25, text: '注意一轮完整呼吸：开始、中间、结束。'),
        MeditationStep(startSecond: 60, text: '分心出现时，不责备自己，只说：分心了，然后回来。'),
        MeditationStep(startSecond: 100, text: '把今天接下来最重要的一件事，轻轻放在心里。'),
        MeditationStep(startSecond: 145, text: '吸气，知道我在这里。呼气，准备做一件具体的事。'),
        MeditationStep(startSecond: 200, text: '不需要完美开始，只需要开始第一个小动作。'),
        MeditationStep(startSecond: 260, text: '最后，把注意力放回眼前：下一步，我只做一件事。'),
      ],
      endingReflection: '专注不是没有分心，而是分心后知道如何回来。',
    ),
    MeditationSessionTemplate(
      key: 'body_scan_10m',
      title: '10分钟身体扫描',
      type: '身体扫描',
      category: '身体扫描',
      description: '从头到脚扫描身体，让紧绷慢慢被看见。',
      durationSeconds: 600,
      steps: [
        MeditationStep(startSecond: 0, text: '找一个舒服的姿势。让身体被支撑，不必用力维持。'),
        MeditationStep(startSecond: 40, text: '先感受头顶、额头和眼周。让眉心稍微松一点。'),
        MeditationStep(startSecond: 100, text: '感受脸颊、下巴和喉咙。如果紧绷，只要看见它。'),
        MeditationStep(startSecond: 170, text: '把注意力带到肩膀、手臂、手掌。感受重量和温度。'),
        MeditationStep(startSecond: 250, text: '感受胸口和背部。呼吸正在这里自然起伏。'),
        MeditationStep(startSecond: 330, text: '感受腹部、腰部和骨盆。允许身体暂时不需要表现。'),
        MeditationStep(startSecond: 420, text: '感受大腿、小腿、脚踝和脚底。脚底正在接触地面或床。'),
        MeditationStep(startSecond: 515, text: '现在感受整个身体作为一个整体，正在呼吸，正在存在。'),
        MeditationStep(startSecond: 570, text: '最后一小段时间，什么也不用做。只是安静地在这里。'),
      ],
      endingReflection: '你不是一台一直运转的机器，你也可以回到身体里休息。',
    ),
    MeditationSessionTemplate(
      key: 'sleep_release_10m',
      title: '停止反刍入睡',
      type: '睡前放松',
      category: '睡眠',
      description: '睡前不再继续喂养白天的念头，让身体进入夜晚。',
      durationSeconds: 600,
      isSleep: true,
      steps: [
        MeditationStep(startSecond: 0, text: '现在是睡前时间。今天没有处理完的事，可以先放到明天。'),
        MeditationStep(startSecond: 45, text: '感受身体躺着或坐着，被床、椅子或地面支撑。'),
        MeditationStep(startSecond: 110, text: '如果白天的画面出现，在心里说：我知道你来了，但现在我要休息。'),
        MeditationStep(startSecond: 180, text: '让呼气比吸气稍微长一点。慢慢呼气，像把一天放下来。'),
        MeditationStep(startSecond: 260, text: '从额头开始放松，然后是眼睛、脸颊、下巴。'),
        MeditationStep(startSecond: 350, text: '肩膀不需要再扛着今天。手臂、手掌可以慢慢变沉。'),
        MeditationStep(startSecond: 450, text: '腹部、腿、脚，也可以安静下来。'),
        MeditationStep(startSecond: 540, text: '如果又开始想事情，只要回来听见呼吸。今晚，先睡觉。'),
      ],
      endingReflection: '今天已经到这里。剩下的事，可以交给明天的你。',
    ),
    MeditationSessionTemplate(
      key: 'self_acceptance_6m',
      title: '6分钟自我接纳',
      type: '自我接纳',
      category: '自我接纳',
      description: '失败、自责、羞耻之后，先停止继续攻击自己。',
      durationSeconds: 360,
      steps: [
        MeditationStep(startSecond: 0, text: '先把手轻轻放在胸口或腹部，感受身体的温度。'),
        MeditationStep(startSecond: 35, text: '此刻也许并不容易。先承认：我正在经历困难。'),
        MeditationStep(startSecond: 80, text: '很多人都会有失败、自责、羞耻的时刻。我并不是唯一这样的人。'),
        MeditationStep(startSecond: 130, text: '吸气时，感受身体还在这里。呼气时，对自己少一点攻击。'),
        MeditationStep(startSecond: 190, text: '我可以为错误负责，但不必把自己整个人否定掉。'),
        MeditationStep(startSecond: 260, text: '愿我从这一刻开始，重新对自己温和一点，也更诚实一点。'),
        MeditationStep(startSecond: 325, text: '最后提醒自己：我可以重新开始，从一个小行动开始。'),
      ],
      endingReflection: '接纳不是放弃改变，而是停止在改变之前先摧毁自己。',
    ),

    MeditationSessionTemplate(
      key: 'attention_sovereignty_8m',
      title: '8分钟注意力主权恢复',
      type: '注意力主权',
      category: '个性化恢复',
      description: '被外界刺激、羞辱或捉弄后，把注意力从对方那里收回来。',
      durationSeconds: 480,
      steps: [
        MeditationStep(startSecond: 0, text: '先坐稳。你不需要马上证明什么，也不需要立刻在脑中反击。'),
        MeditationStep(startSecond: 35, text: '感受脚底、腿、背部和身体的重量。你此刻在这里，不在那个人的眼光里。'),
        MeditationStep(startSecond: 75, text: '如果脑中出现对方的表情、话语、动作，只需轻轻标记：这是被触发后的回放。'),
        MeditationStep(startSecond: 120, text: '吸气，知道自己被影响了。呼气，先不继续把注意力交给他。'),
        MeditationStep(startSecond: 165, text: '在心里说：我看见这个刺激，但我不把今天剩下的时间献给它。'),
        MeditationStep(startSecond: 210, text: '让注意力回到身体最稳定的地方。也许是脚底，也许是手掌，也许是腹部的起伏。'),
        MeditationStep(startSecond: 260, text: '念头如果说：我要想明白、我要赢回来、我要证明他错了。只需要回答：现在先回来。'),
        MeditationStep(startSecond: 315, text: '真正的主动权，不是让对方消失，而是我不再继续用自己的注意力喂养他。'),
        MeditationStep(startSecond: 370, text: '感受一次完整的吸气，再感受一次完整的呼气。回来，不是软弱；回来，是收回主权。'),
        MeditationStep(startSecond: 430, text: '最后，把注意力放到今天还能做的一件小事上。只是一件，很小也可以。'),
      ],
      endingReflection: '你把注意力从外界刺激中收回了一次，这就是重新掌握自己的开始。',
    ),
    MeditationSessionTemplate(
      key: 'shame_self_blame_release_9m',
      title: '9分钟羞耻与自责松绑',
      type: '自责松绑',
      category: '自我接纳',
      description: '当内疚、自责、羞耻开始攻击自己时，练习负责但不自毁。',
      durationSeconds: 540,
      steps: [
        MeditationStep(startSecond: 0, text: '把一只手轻轻放在胸口或腹部。先让身体知道：此刻不是审判时间。'),
        MeditationStep(startSecond: 40, text: '如果你正在责备自己，先承认：我现在很难受，我正在经历一股自我攻击。'),
        MeditationStep(startSecond: 85, text: '吸气时，感受手掌的温度。呼气时，对自己少一点用力。'),
        MeditationStep(startSecond: 130, text: '羞耻常常会说：我整个人都不够好。现在只需要看见，这是一种感受，不是最终判决。'),
        MeditationStep(startSecond: 180, text: '我可以承认错误、承认脆弱、承认没有做好，但不必把自己整个人判成失败。'),
        MeditationStep(startSecond: 235, text: '把注意力放回呼吸。每次呼气，都像从自责的绳子里松开一毫米。'),
        MeditationStep(startSecond: 295, text: '在心里说：我愿意为可以改变的部分负责，也愿意停止继续伤害自己。'),
        MeditationStep(startSecond: 355, text: '如果又出现批判的声音，只需要说：我听见了，但我现在选择一种更能恢复力量的方式。'),
        MeditationStep(startSecond: 420, text: '想象自己不是被审判的人，而是一个正在恢复、正在学习、正在重新站起来的人。'),
        MeditationStep(startSecond: 490, text: '最后，轻轻问自己：接下来一个善待自己、同时不逃避责任的小行动是什么？'),
      ],
      endingReflection: '接纳不是逃避责任，而是让你不用通过摧毁自己来证明自己有责任感。',
    ),
    MeditationSessionTemplate(
      key: 'dignity_softening_10m',
      title: '10分钟体面防御安放',
      type: '体面安放',
      category: '个性化恢复',
      description: '当强烈体面感让你必须独自硬撑时，练习把尊严从防御中放松出来。',
      durationSeconds: 600,
      steps: [
        MeditationStep(startSecond: 0, text: '先不用表现坚强。此刻只需要坐着，感受身体被支撑。'),
        MeditationStep(startSecond: 45, text: '你可能习惯了独自解决、隐蔽承受、尽量不求人。先看见这个模式，不急着改变它。'),
        MeditationStep(startSecond: 105, text: '吸气时，感受胸口。呼气时，让肩膀放下一点点不必被别人看见的重量。'),
        MeditationStep(startSecond: 165, text: '体面曾经保护过你。它让你在困难中不轻易垮掉，也让你保存了一部分尊严。'),
        MeditationStep(startSecond: 230, text: '但此刻，你可以尝试区分：尊严不是必须一个人硬撑，尊严也可以包括照顾自己。'),
        MeditationStep(startSecond: 300, text: '如果心里出现抗拒，只需要说：我不是要丢掉体面，我只是让身体不再一直处于战斗。'),
        MeditationStep(startSecond: 370, text: '把注意力放到背部。感受背部被支撑，而不是永远独自支撑全部生活。'),
        MeditationStep(startSecond: 440, text: '在心里说：我可以保持尊严，也可以学习接受合适的帮助。两者并不矛盾。'),
        MeditationStep(startSecond: 510, text: '最后几次呼吸，让身体记住：真正稳固的自尊，不需要一直紧绷来证明。'),
        MeditationStep(startSecond: 565, text: '把今天一个可以减轻负担的小选择放在心里，不需要很大，只要真实。'),
      ],
      endingReflection: '你不是放弃尊严，而是在把尊严从孤立硬撑中慢慢解放出来。',
    ),
    MeditationSessionTemplate(
      key: 'body_home_after_pain_8m',
      title: '8分钟痛苦承受后的身体回家',
      type: '身体回家',
      category: '身体扫描',
      description: '经历疼痛、疲惫或长期紧绷后，让身体知道现在可以慢慢恢复。',
      durationSeconds: 480,
      steps: [
        MeditationStep(startSecond: 0, text: '找一个让身体相对舒服的姿势。先不要求放松，只要求诚实地感受。'),
        MeditationStep(startSecond: 35, text: '也许身体曾经承受过很多疼痛、惊慌、无助和硬撑。现在先对身体说：我看见你了。'),
        MeditationStep(startSecond: 85, text: '把注意力放在脚底。感受接触、重量、温度。让脚底成为此刻的锚点。'),
        MeditationStep(startSecond: 135, text: '慢慢来到腿部。不是检查哪里有问题，而是感受身体仍然在支持你。'),
        MeditationStep(startSecond: 190, text: '来到腹部和腰部。呼吸经过这里时，让身体知道：现在不是紧急时刻。'),
        MeditationStep(startSecond: 245, text: '如果有不舒服，只在心里轻轻命名：紧、酸、沉、热、空。命名之后，回到呼吸。'),
        MeditationStep(startSecond: 305, text: '来到胸口、肩膀和背部。让每一次呼气都卸下一点长期防备。'),
        MeditationStep(startSecond: 365, text: '来到脸、额头和眼睛。让表情不必再替你承受全部压力。'),
        MeditationStep(startSecond: 425, text: '最后，感受整个身体。它不是你的敌人，它曾经陪你穿过很多难关。'),
      ],
      endingReflection: '你的身体不只是痛苦的现场，也是你一步步恢复的地方。',
    ),
    MeditationSessionTemplate(
      key: 'action_start_stability_9m',
      title: '9分钟行动启动前稳定',
      type: '行动启动',
      category: '专注回收',
      description: '当任务堆积、拖延、内耗时，先稳定身体，再启动一个最小行动。',
      durationSeconds: 540,
      steps: [
        MeditationStep(startSecond: 0, text: '先停下来。你不需要一次解决全部任务，只需要重新回到可行动的状态。'),
        MeditationStep(startSecond: 40, text: '感受脚底和座椅。让身体先落地，头脑不必继续在所有任务之间奔跑。'),
        MeditationStep(startSecond: 85, text: '吸气时，知道自己有压力。呼气时，先不把压力解释成失败。'),
        MeditationStep(startSecond: 135, text: '如果脑中出现“太多了、来不及了、我又失败了”，只标记：这是压力语言。'),
        MeditationStep(startSecond: 190, text: '把今天所有任务暂时放远一点。现在只找一件最小、最具体、能开始的动作。'),
        MeditationStep(startSecond: 250, text: '这个动作可以小到打开页面、写第一行、整理一个文件、站起来走两分钟。'),
        MeditationStep(startSecond: 315, text: '在心里说：我不是靠情绪准备好才开始，我是通过开始一点点找回状态。'),
        MeditationStep(startSecond: 380, text: '继续呼吸。让注意力从“整个人生怎么办”回到“下一步做什么”。'),
        MeditationStep(startSecond: 450, text: '现在把那个最小动作在心里说清楚：练习结束后，我先做……'),
        MeditationStep(startSecond: 505, text: '最后一小段时间，感受身体的稳定。然后带着不完美，开始第一步。'),
      ],
      endingReflection: '行动不需要等到完全有力量才开始；很多时候，力量是在开始之后慢慢回来。',
    ),
    MeditationSessionTemplate(
      key: 'scarcity_safety_rebuild_10m',
      title: '10分钟匮乏记忆安全感重建',
      type: '安全感重建',
      category: '个性化恢复',
      description: '当旧的匮乏、饥饿、无助感被激活时，练习把身体带回当下的安全。',
      durationSeconds: 600,
      steps: [
        MeditationStep(startSecond: 0, text: '先环顾一下周围。看见三个真实存在的物体，让眼睛告诉身体：我在现在。'),
        MeditationStep(startSecond: 50, text: '感受脚底或身体和支撑物的接触。此刻，你可以先不用逃、也不用马上解决全部问题。'),
        MeditationStep(startSecond: 110, text: '如果旧的匮乏感、无助感、被抛下的感觉出现，只需要说：这是旧记忆被激活了。'),
        MeditationStep(startSecond: 175, text: '吸气，感受现在的空气。呼气，告诉身体：那是过去的危险信号，不一定是此刻的全部事实。'),
        MeditationStep(startSecond: 245, text: '把一只手放在胸口或腹部，给身体一个明确的触点。让它知道：有人在这里照看我。'),
        MeditationStep(startSecond: 315, text: '你曾经用尽办法活下来。现在的练习，不是回到那些画面，而是把自己带离旧的紧急状态。'),
        MeditationStep(startSecond: 385, text: '慢慢呼气。每一次呼气，都像告诉身体：现在我可以用更安全的方式保护自己。'),
        MeditationStep(startSecond: 455, text: '如果头脑又开始预演最坏结果，轻轻回到触点、脚底、呼吸、房间里的声音。'),
        MeditationStep(startSecond: 530, text: '最后，在心里说：我正在从生存模式，慢慢走向生活模式。一步一步就够了。'),
      ],
      endingReflection: '曾经的匮乏说明你承受过很多；现在的练习，是让身体重新学习安全。',
    ),
    MeditationSessionTemplate(
      key: 'calm_mountain_8m',
      title: '8分钟清风拂山岗定力',
      type: '定力练习',
      category: '个性化恢复',
      description: '训练“不慌不忙、不被打乱节奏”的内在稳定。',
      durationSeconds: 480,
      steps: [
        MeditationStep(startSecond: 0, text: '坐稳。想象自己不是在风中摇摆的草，而是一座安静的山。'),
        MeditationStep(startSecond: 35, text: '吸气时，感受身体向上。呼气时，感受身体向下落地。'),
        MeditationStep(startSecond: 80, text: '外界可以有声音、变化、评价、挑衅。你不需要马上跟着它们移动。'),
        MeditationStep(startSecond: 125, text: '在心里轻轻说：他强任他强，清风拂山岗。'),
        MeditationStep(startSecond: 170, text: '这不是麻木，也不是忍气吞声。而是在行动之前，先不让自己的节奏被夺走。'),
        MeditationStep(startSecond: 225, text: '如果念头想冲出去辩解、证明、反击，先把注意力放回脊背和脚底。'),
        MeditationStep(startSecond: 285, text: '让呼吸像山间的风，来，又走；念头也来，又走。你只需要稳稳坐着。'),
        MeditationStep(startSecond: 350, text: '真正的定力，是我知道发生了什么，也知道我不必立刻被它牵着走。'),
        MeditationStep(startSecond: 420, text: '最后几次呼吸，带着这份稳定回到今天：慢一点，稳一点，做自己的事。'),
      ],
      endingReflection: '你练习的不是压抑反应，而是在反应之前保留自己的节奏。',
    ),
    MeditationSessionTemplate(
      key: 'self_worth_repair_11m',
      title: '11分钟价值感修复',
      type: '自尊修复',
      category: '自我接纳',
      description: '当长期挫败、能力受限或被现实卡住时，重新区分“受阻”与“无价值”。',
      durationSeconds: 660,
      steps: [
        MeditationStep(startSecond: 0, text: '先坐下来。此刻不需要证明自己有价值，只需要给自己一点稳定空间。'),
        MeditationStep(startSecond: 50, text: '感受呼吸。吸气，身体还在。呼气，暂时放下那个“我必须马上证明自己”的压力。'),
        MeditationStep(startSecond: 115, text: '也许你曾经长期努力，却被某些现实限制、岗位限制、身体条件或机会卡住。先承认：这很痛。'),
        MeditationStep(startSecond: 185, text: '在心里说：受阻，不等于无能；没有被看见，不等于没有价值。'),
        MeditationStep(startSecond: 255, text: '把注意力放到双手。双手曾经工作、学习、忍耐、尝试，它们不是失败的证据。'),
        MeditationStep(startSecond: 330, text: '如果脑中出现“我不如别人、我浪费了时间、我没出息”，只标记：这是受挫后的自我否定。'),
        MeditationStep(startSecond: 405, text: '现在练习一个新的区分：我可以承认路走得很难，同时不把自己整个人否定掉。'),
        MeditationStep(startSecond: 480, text: '吸气，感受还没有消失的愿望。呼气，允许这个愿望用更现实、更稳的方式继续存在。'),
        MeditationStep(startSecond: 550, text: '价值感不是一次成功给你的，也不是一次失败拿走的。它可以通过每天一个真实行动慢慢重建。'),
        MeditationStep(startSecond: 620, text: '最后，问自己：今天我可以做哪一个很小但能支持自己的行动？'),
      ],
      endingReflection: '现实可能让一条路受阻，但它不能证明你整个人没有价值。',
    ),
  ];

  static MeditationSessionTemplate defaultForState(String state) {
    switch (state) {
      case '被外界影响':
      case '被羞辱后反刍':
        return byKey('attention_sovereignty_8m');
      case '自责羞耻':
        return byKey('shame_self_blame_release_9m');
      case '行动卡住':
        return byKey('action_start_stability_9m');
      case '身体紧绷':
        return byKey('body_home_after_pain_8m');
      case '需要定力':
        return byKey('calm_mountain_8m');
      case '价值感受挫':
        return byKey('self_worth_repair_11m');
      case '焦虑紧张':
      case '心很乱':
        return byKey('breath_anchor_3m');
      case '疲惫无力':
        return byKey('body_scan_10m');
      case '想专注':
        return byKey('focus_return_5m');
      case '睡前放松':
        return byKey('sleep_release_10m');
      case '日常练习':
      default:
        return byKey('calm_mountain_8m');
    }
  }

  static MeditationSessionTemplate byKey(String key) {
    return sessions.firstWhere((e) => e.key == key, orElse: () => sessions.first);
  }

  static Map<String, List<MeditationSessionTemplate>> groupedByCategory({bool sleepOnly = false}) {
    final Map<String, List<MeditationSessionTemplate>> result = {};
    for (final session in sessions) {
      if (sleepOnly && !session.isSleep) continue;
      if (!sleepOnly && session.isSleep) continue;
      result.putIfAbsent(session.category, () => <MeditationSessionTemplate>[]).add(session);
    }
    return result;
  }
}
