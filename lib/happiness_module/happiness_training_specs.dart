import 'happiness_models.dart';

class HappinessConceptLens {
  final String definition;
  final String experience;
  final String realWorld;
  final String practice;
  const HappinessConceptLens({required this.definition, required this.experience, required this.realWorld, required this.practice});
}

class HappinessBehaviorSpec {
  final String trigger;
  final String thought;
  final String body;
  final String oldPattern;
  final String newPattern;
  final String fact;
  const HappinessBehaviorSpec({
    required this.trigger,
    required this.thought,
    required this.body,
    required this.oldPattern,
    required this.newPattern,
    required this.fact,
  });
}

HappinessConceptLens conceptLensFor(HappinessUnit unit, String concept) {
  switch (concept) {
    case '失败是学习机制':
      return HappinessConceptLens(
        definition: '在这一段里，它指“学会一项能力，本来就要经历做不好、摔倒、修正、再试”。失败不是人格证据，而是训练反馈。',
        experience: '当你想开始一件新事时，脑中会冒出“我现在这么笨拙是不是不适合”，身体会有一点僵、怕出丑、怕留下差印象；如果你允许自己先笨拙一次，紧张通常会慢慢下降。',
        realWorld: '常见在第一次发言、第一次投稿、第一次做作品、第一次表白、第一次带团队时。人不是不会，而是想把“第一回合”直接做成“成熟版本”。',
        practice: '今天选一个你还没熟练的动作，只要求自己“完成第一次样本”，例如发出一版粗稿、做一次三分钟练习、开口问一个问题。完成后只记录学到什么。',
      );
    case '试错':
      return HappinessConceptLens(
        definition: '它强调能力不是靠脑内想出来，而是靠一轮轮“先做—发现偏差—调整”长出来。',
        experience: '你会一边做一边发现“这里不会”“那里不顺”，这会让人有点烦、有点羞耻，也容易想停下来重新准备。',
        realWorld: '常见在写作、剪视频、做方案、谈合作、练表达。真正进步的不是一直准备的人，而是不断拿到反馈的人。',
        practice: '把今天的任务改成“做出一个可反馈样本”，而不是“做出完美作品”。做完后只问：哪个地方最值得改下一轮？',
      );
    case '恢复':
    case '恢复力':
      return HappinessConceptLens(
        definition: '在这几段里，它指“做砸后还能回来”，而不是一次受挫后直接退出、封闭或自我判死刑。',
        experience: '不顺以后，心里会想躲开、删掉、装没发生；身体可能会沉、紧、想拖延。恢复不是不难受，而是难受后还能回到下一步。',
        realWorld: '常见在被拒绝、发言卡壳、和伴侣吵架、计划被打乱、工作出错之后。',
        practice: '给自己准备一条“失败后 10 分钟内能做的恢复动作”，例如补一句说明、重发一次、写下学到的一点、把动作缩小后继续。',
      );
    case '评价焦虑':
      return HappinessConceptLens(
        definition: '它不是事情本身有多难，而是“别人会怎么想我”占据了你的注意力。',
        experience: '脑中常出现“别人会不会觉得我很蠢/很差/很冒犯”，身体会先收紧，喉咙发涩、想撤回。',
        realWorld: '常见在会议发言、向上反馈、发朋友圈、表达需求、主动搭话、向喜欢的人示好。',
        practice: '在一个安全但真实的场景里，说出一句你通常会吞回去的话，例如补一个观点、提一个问题、表达一个小需求。重点不是表现好，而是不要再次消失。',
      );
    case '回避':
      return HappinessConceptLens(
        definition: '它指为了暂时不难受，选择不做、不说、不面对；短期像保护自己，长期却让你越来越怕。',
        experience: '当任务靠近时，你会想“再等等”“先准备好再说”，看似理性，实则在拖开和真实世界接触。',
        realWorld: '常见在拖着不回消息、不投简历、不交稿、不问清楚、不谈冲突、不做决定。',
        practice: '把今天最想拖开的那件事压缩成一个接触动作：发出一条消息、预约一个时间、打开文档写三句、问一个澄清问题。',
      );
    case '自我保护':
      return HappinessConceptLens(
        definition: '这里不是健康边界，而是那种“为了不受伤，先别去试”的心理保护。',
        experience: '你会把“不出现”解释成“我很谨慎”，但心里其实知道自己在躲失望、躲丢脸。',
        realWorld: '常见在不主动、不争取、不暴露真实心意，也常见在过度准备、过度控制。',
        practice: '问自己：我现在是在保护边界，还是在保护自尊不被碰？如果更像后者，就做一个非常小的出现动作。',
      );
    case '灾难化':
      return HappinessConceptLens(
        definition: '把一次可能不顺，直接脑补成“整件事都完了”“我的形象完了”“以后都完了”。',
        experience: '脑中跳得很快，往往几秒内就从“小风险”跳到“大灾难”，身体会跟着紧、急、想逃。',
        realWorld: '常见在汇报、面试、被已读不回、提交作品、做决定前。',
        practice: '把脑中最吓人的一句话原样写出来，再写它真正对应的可验证事件是什么。先把“完了”拆成几个具体后果。',
      );
    case '最坏情况重估':
      return HappinessConceptLens(
        definition: '不是假装没风险，而是把“最坏到底是什么”认真写清楚，重新评估它的概率与代价。',
        experience: '一旦你开始写具体后果，情绪通常会从模糊巨大，变成可分析、可应对。',
        realWorld: '常见在换工作、发出请求、公开表达、做选择、承担责任前。',
        practice: '针对一件回避中的事，写三列：最坏结果、我如何应对、即使发生我能学到什么。写完再决定要不要迈一步。',
      );
    case '可承受性':
      return HappinessConceptLens(
        definition: '课程强调的不是“肯定会赢”，而是“即使不顺，我是否仍能活、能学、能调整”。',
        experience: '当你意识到“原来我扛得住”，身体会从完全冻结变成有一点空间。',
        realWorld: '常见在面对拒绝、差评、公开失误、关系冷场时。',
        practice: '对一件怕做的事，先不要问“能不能保证成功”，改问“如果不顺，我撑不撑得住、怎么撑”。',
      );
    case '长期尺度':
      return HappinessConceptLens(
        definition: '把这一次放回更长的时间线，不再用一个节点定义整条人生。',
        experience: '当你只盯当前结果时，会特别刺痛；拉长到一年、三年、五年看，情绪常会松动。',
        realWorld: '常见在考试失利、项目出错、竞选落选、关系一次冲突后。',
        practice: '写一句“如果把时间拉到三年后，这次更可能是毁掉一切，还是成为我成长轨迹的一部分？”',
      );
    case '非线性成功':
      return HappinessConceptLens(
        definition: '成功不是每一步都更好，而是常常有回撤、绕路、暂停、重来。',
        experience: '人一遇到退步就容易以为“白做了”，但非线性视角会提醒你：波动不等于倒退。',
        realWorld: '常见在创业、学习、作品积累、职业路径、亲密关系修复中。',
        practice: '拿最近一次挫折，补上“这次没有让我更顺，但可能让我更稳/更清楚/更会选”。',
      );
    case '韧性':
      return HappinessConceptLens(
        definition: '韧性不是硬扛不难受，而是难受后还能回来，再次上场。',
        experience: '你会伤、会挫败、会丢脸，但不会把自己永远留在那个点上。',
        realWorld: '常见在连续被拒绝、连续练习、连续修改中。',
        practice: '给自己定义“再次上场”的最小版本，例如今天不要求成功，只要求重新出现一次。',
      );
    case '示范性不完美':
      return HappinessConceptLens(
        definition: '不是故意做差，而是当小差错出现时，不再急着把它抹掉。',
        experience: '你会很想解释、补救、证明自己其实很专业，但练习是不急着用完美掩盖人性。',
        realWorld: '常见在上课、开会、主持、演讲、带团队时的小失误。',
        practice: '今天如果出现一个小差错，先正常继续，不立刻过度补偿。事后只补一句必要说明。',
      );
    case '允许偏差':
      return HappinessConceptLens(
        definition: '接受事情偏离理想版本一点点，而不是一偏离就判成失败。',
        experience: '当你允许偏差，内心会从“必须纠正到零误差”变成“可以先往前”。',
        realWorld: '常见在时间安排、任务完成度、表达状态、关系互动里。',
        practice: '给今天一件事设“够好线”，只要过线就不继续耗。',
      );
    case '螺旋成长':
      return HappinessConceptLens(
        definition: '它不是直线进步，而是你会回来、重复、再理解更深一层。',
        experience: '你可能会觉得“怎么又回到这个问题”，但其实这次回来，你的位置和理解已经不同。',
        realWorld: '常见在情绪管理、表达、自我价值、关系修复中。问题常会反复出现，但不是原地打转。',
        practice: '把最近一次“又来了”的时刻改写成：我不是退回原点，而是又来到这一层的练习。',
      );
    case '练习中的失败':
      return HappinessConceptLens(
        definition: '在练习阶段做不好，恰恰说明你在练的是真东西。',
        experience: '你会觉得笨、卡、重复犯错，但这恰恰说明你还在真实的成长区。',
        realWorld: '常见在任何新技能起步期，以及旧技能升级期。',
        practice: '今天故意保留一次笨拙练习的痕迹，不把它藏起来，提醒自己这叫训练，不叫证明自己差。',
      );
    case '模式迁移':
      return HappinessConceptLens(
        definition: '换了环境，旧的内在剧本仍会跟着走。',
        experience: '你可能以为“只要换学校/工作/关系就好了”，结果熟悉的紧绷又出现。',
        realWorld: '常见在从校园到职场、从单身到恋爱、从一个项目到另一个项目时。',
        practice: '写一句“我在不同场景里最常重复的旧剧本是什么”，先识别它而不是继续怪环境。',
      );
    case '身份转换':
      return HappinessConceptLens(
        definition: '身份改变会带来失落、重新证明自己、以及把旧控制感带进新角色。',
        experience: '当旧身份失效，你会特别想在新身份里赶紧站稳、赶紧证明自己。',
        realWorld: '常见在换专业、换岗位、转型、成为父母或管理者时。',
        practice: '写出“我现在最急着证明的新身份是什么”，再问它是不是把我推回了旧完美主义。',
      );
    case '控制感':
      return HappinessConceptLens(
        definition: '很多完美主义并不是追求更好，而是在追求“事情别失控”。',
        experience: '一旦有变量、临时变化、别人不按你想的来，你会特别焦躁。',
        realWorld: '常见在学业安排、项目推进、亲密关系、育儿、团队协作里。',
        practice: '今天挑一件小事，不把所有变量都抓在手里，允许一个可控范围内的不确定。',
      );
    case '抱负':
      return HappinessConceptLens(
        definition: '抱负是你真正在乎的方向和高度，不等于必须用完美主义来实现。',
        experience: '当抱负和完美主义混在一起时，你会一边想做大事，一边被“不能出错”卡死。',
        realWorld: '常见在学业、创业、创作、职业发展上。',
        practice: '把一个目标改写成“我想认真做到什么”，而不是“我绝不能有任何偏差”。',
      );
    case '完美主义':
      return HappinessConceptLens(
        definition: '在这些单元里，它不是“标准高”，而是“无法容忍偏差和失败，一偏离就攻击自己”。',
        experience: '脑中常有“必须一次到位”“不能显得笨”“不能让人失望”，身体会长期紧绷，行为上不是过度控制就是干脆拖着不做。',
        realWorld: '常见在提交作品、准备汇报、进入关系、管理身体、接受反馈时。',
        practice: '今天不要练“彻底摆脱完美主义”，只练一个小地方：允许一处不完美存在，同时继续推进重要事情。',
      );
    case '失败态度':
      return HappinessConceptLens(
        definition: '关键差异不在有没有失败，而在你把失败解释成什么。',
        experience: '同样一次不顺，有人会说“我完了”，有人会说“这里要重练”。',
        realWorld: '常见在考试、汇报、关系冲突、面试失利后。',
        practice: '把最近一次失败的标题从“我不行”改成“我需要重练的地方是……”。',
      );
    case '草稿意识':
    case '允许粗糙输出':
      return HappinessConceptLens(
        definition: '先允许有第一版、粗稿、样稿，进步才会真的开始。',
        experience: '你会很想“再等等，先打磨好”，但粗稿意识会提醒你：没有第一版，就没有后面的优化。',
        realWorld: '常见在写作、设计、代码、作品集、汇报稿里。',
        practice: '限定时间做一版 70 分成品，到点就输出给现实世界看。',
      );
    case '直线思维':
      return HappinessConceptLens(
        definition: '认为通往成功、关系、成长的路应该一路顺、一路对、一路直达。',
        experience: '一旦绕路、退步、被打断，就会立刻觉得“这条路不对”“我不适合”。',
        realWorld: '常见在学习计划、职业发展、亲密关系、育儿、自我成长中。',
        practice: '遇到一个波动时，不急着改判整条路，先写下“这更像正常曲线中的哪一种：绕路、停顿、回撤还是重练”。',
      );
    case '卓越':
      return HappinessConceptLens(
        definition: '追求卓越不是降低标准，而是把标准和现实的成长规律放在一起。',
        experience: '你依然认真、依然想做得好，但不会因为一个偏差就全盘否定。',
        realWorld: '常见在长期训练者、成熟创作者、好管理者身上：他们强要求，但不迷信直线。',
        practice: '对今天的重要任务设“卓越版目标”：认真完成、允许调整、允许学习，而不是要求无瑕。',
      );
    case '防御性':
      return HappinessConceptLens(
        definition: '一听到批评、不同意见或现实反馈，立刻想解释、反驳、保护自己。',
        experience: '身体会先绷住，脑子里迅速跳出一堆辩解词，甚至在对方没说完前就想打断。',
        realWorld: '常见在绩效反馈、伴侣沟通、同事协作、师生关系里。',
        practice: '下一次收到反馈时，先只回一句“我先听完”，不立刻解释。之后再决定怎么回应。',
      );
    case '半杯空':
      return HappinessConceptLens(
        definition: '注意力习惯性落在“还不够、还没做到、哪里有问题”。',
        experience: '你做成了 80%，脑子却只盯着那 20% 的缺口。',
        realWorld: '常见在成绩、工作成果、外貌身材、关系满意度中。',
        practice: '完成一件事后，强制先写 3 条已经存在的有效部分，再去看不足。',
      );
    case '全有或全无':
      return HappinessConceptLens(
        definition: '不是全对就是全错，不是最好就是失败，没有中间地带。',
        experience: '一点偏差就会被你解释成彻底失败，情绪会特别陡。',
        realWorld: '常见在饮食、执行计划、学习效率、关系期待中。',
        practice: '今天刻意练一次“中间地带”：做到 60–80% 也算一次完成，而不是直接作废。',
      );
    case '僵硬':
      return HappinessConceptLens(
        definition: '只接受一种正确做法、一种节奏、一种结果。',
        experience: '一旦计划改了、别人做法不同了、环境变化了，你会很不舒服。',
        realWorld: '常见在流程控制、育儿、团队合作、学习安排里。',
        practice: '给今天一件事预留一个可变方案，练习不按原计划也能继续。',
      );
    case 'relief':
    case '终点崇拜':
    case '下一站陷阱':
      return HappinessConceptLens(
        definition: '把目标达成后的“松一口气”误当成真正幸福，并立刻把幸福延期到下一个目标。',
        experience: '完成时会短暂轻一下，但很快脑中又跳到下一个必须完成的点。',
        realWorld: '常见在考试、升职、项目节点、健身目标、收入目标之后。',
        practice: '完成一件事后，先停留两分钟，记录过程里的成长和感受，不要马上奔向下一站。',
      );
    case '极端化':
    case '节制—放纵摆动':
      return HappinessConceptLens(
        definition: '系统只能接受“完全控制”或“彻底放弃”，于是在人和事上反复摇摆。',
        experience: '你会一开始特别严、特别狠，一旦破一点就索性全部松掉。',
        realWorld: '常见在饮食、作息、学习计划、消费、自律项目中。',
        practice: '今天刻意做一个“适度版本”，让身体和心理都看到中间地带是可行的。',
      );
    case '自我接纳':
      return HappinessConceptLens(
        definition: '接纳自己是个会犯错、有局限、也仍值得继续努力的人。',
        experience: '不是自我放弃，而是不用每一次偏差都证明“我不值得”。',
        realWorld: '常见在成绩、外貌、亲密关系、工作表现的自我评价里。',
        practice: '今天在一个你容易攻击自己的点上，练习只描述事实，不下人格判决。',
      );
    case '投射':
    case '理想化':
    case '理想化幻象':
    case '关系修复':
      return HappinessConceptLens(
        definition: '把自己不能接受的完美要求投到关系里，先理想化，再因现实落差而失望，最后需要学习修复。',
        experience: '你会希望对方“应该懂、应该不犯错、应该一直稳定”，一旦不符就很受伤或很生气。',
        realWorld: '常见在伴侣、朋友、家人、合作关系里。',
        practice: '下一次失望时，不先给对方下定义，先说出“我具体在哪件事上失望了，我想怎么修”。',
      );
    case '长期表现':
    case '可持续成长':
      return HappinessConceptLens(
        definition: '靠高压、完美主义冲出来的成绩常常不可持续；真正稳的是能持续做下去的模式。',
        experience: '你可能短期爆发，但很快耗尽、厌烦、回避。',
        realWorld: '常见在高压备考、冲刺项目、自我管理中。',
        practice: '把一个目标改成“我连续做 7 天也能承受的版本”，而不是爆冲两天后崩掉。',
      );
    case '社会比较':
    case '外部模板':
      return HappinessConceptLens(
        definition: '不断拿自己和外部的“理想模板”比，最后只会更看不见真实的人生与身体。',
        experience: '刷到某种理想图景后，脑中会立刻冒出“我差太多了”。',
        realWorld: '常见在社交媒体、职场榜样、关系想象、身材标准里。',
        practice: '记录今天一个触发比较的外部模板，再问：它真实吗？完整吗？适合我吗？',
      );
    case '固定型思维':
    case '成长型思维':
    case '反馈方式':
      return HappinessConceptLens(
        definition: '固定型思维更在意证明“我本来就行”；成长型思维更在意“我怎样继续学”。反馈方式会推高其中一种。',
        experience: '被夸“你真聪明”时，人更怕碰难题；被看见“你这次很努力”时，更愿意继续练。',
        realWorld: '常见在教育、育儿、团队带人、自我对话里。',
        practice: '今天把一句结果式评价改成过程式反馈，例如把“你好厉害”改成“你这次哪里练得很扎实”。',
      );
    case '20/80':
    case '优先级':
    case '够好原则':
      return HappinessConceptLens(
        definition: '不是每件事都值得用最高投入。抓住关键少数，很多时候更有效也更幸福。',
        experience: '你会发现并不是“全都做到极致”才有价值，而是知道哪里该深、哪里该够好。',
        realWorld: '常见在课程选择、工作投入、生活安排、关系经营中。',
        practice: '今天挑一个任务，只做最重要的 20%，并允许其他部分先“够好”。',
      );
    case '觉察':
    case '模式命名':
    case '自我识别':
      return HappinessConceptLens(
        definition: '先看见自己的自动剧本，并给它命名，这样你才有机会不再完全被它带着走。',
        experience: '当模式开始时，你会更早发现：哦，我又在进入“必须一次做好”或“我最好先躲开”的剧本。',
        realWorld: '常见在反馈、任务开始前、关系失望、被打断后。',
        practice: '今天给自己最常见的一个自动剧本起名字，并在它出现时心里点名它。',
      );
    case '尝试强化':
    case '过程强化':
    case '过程奖励':
      return HappinessConceptLens(
        definition: '强化“去试了、坚持了、修正了”这些过程，而不是只在结果赢时才认可。',
        experience: '你会慢慢把注意力从“我赢了吗”移向“我有没有真的在练”。',
        realWorld: '常见在自我鼓励、带孩子、带团队、伴侣支持中。',
        practice: '今天对自己或别人，明确肯定一次“尝试”或“修正”，而不是只夸结果。',
      );
    case '主动接纳':
    case '与问题共处':
      return HappinessConceptLens(
        definition: '不是先把问题彻底消灭，才允许自己往前；而是承认它还在，同时继续活。',
        experience: '你会发现那部分紧张、完美主义、回避还会出现，但你不再把它当成“今天不能动”的理由。',
        realWorld: '常见在长期焦虑、完美主义、关系旧伤、旧创伤模式里。',
        practice: '写一句接纳式的话给自己的老问题，然后今天仍做一个小动作。',
      );
    case '行为先行':
    case '暴露练习':
    case '反馈承受':
      return HappinessConceptLens(
        definition: '很多时候不是想通了才敢做，而是做了以后，脑子才开始更新。暴露练习和承受反馈，就是用行为撬动内部结构。',
        experience: '行动前会紧、会想逃；真正做完后，通常会发现“原来我能承受的比以为的大”。',
        realWorld: '常见在发言、表达需求、索取反馈、发起请求、承认不足时。',
        practice: '今天做一个可承受的小暴露：问一个问题、索取一次反馈、发出一个轻微有被拒绝可能的请求。',
      );
    case '可视化':
    case '冥想':
    case '状态进入':
      return HappinessConceptLens(
        definition: '在现实行动前，先用想象和呼吸把自己带进更稳、更开放的状态。',
        experience: '你会从一上来就紧绷，转成比较能呼吸、能站稳、能看到全局。',
        realWorld: '常见在上台前、开会前、面试前、冲突对话前。',
        practice: '在一件紧张的事前做 3 分钟想象：想象自己以更稳、更真实的状态出现。',
      );
    case '白金法则':
    case '自我慈悲':
    case '双重标准':
      return HappinessConceptLens(
        definition: '别再用你不会那样对待朋友的方式来对待自己。自我慈悲是修正双标，不是放纵。',
        experience: '你会发现，别人犯同样的错你能理解，轮到自己却只剩责骂。',
        realWorld: '常见在工作失误、外貌焦虑、关系失败、自我评价里。',
        practice: '把今天最狠的一句自责，改写成你会对朋友说的话，然后读给自己。',
      );
    case '陪伴方式':
    case '以身作则':
      return HappinessConceptLens(
        definition: '帮助别人时，最有效的常常不是说教，而是示范、分享和奖励过程。',
        experience: '你会少一点“你应该”，多一点“我也经历过、我现在怎么练”。',
        realWorld: '常见在亲密关系、带孩子、朋友支持、团队管理里。',
        practice: '今天如果你想帮一个人，先分享自己的一个真实练习故事，而不是给指令。',
      );
    case 'Permission':
    case 'Positive':
    case 'Perspective':
      final d = concept == 'Permission'
          ? '先允许自己是人，这很难是正常的。'
          : concept == 'Positive'
              ? '在痛苦里不否认痛苦，但仍去找一点学习与益处。'
              : '把视角拉长，不让眼前这一刻变成全部世界。';
      final e = concept == 'Permission'
          ? '崩的时候你最容易先攻击自己，这个 P 要你先停下来，不追加羞耻。'
          : concept == 'Positive'
              ? '情绪很重时，大脑只会看到损失；这个 P 要你把一点可学之处找回来。'
              : '陷进去时世界会缩成眼前一件事；这个 P 要你重新看到更大的时间和空间。';
      final p = concept == 'Permission'
          ? '今天一旦出错，先对自己说一句“这很难，我先允许自己乱一下”。'
          : concept == 'Positive'
              ? '在一个不顺的场景里，写下至少一条这件事逼你看见或学会的东西。'
              : '遇到卡点时，问一句“一年后这件事还会这么大吗？”';
      return HappinessConceptLens(definition: d, experience: e, realWorld: '常见在手忙脚乱、迟到、讲砸、冲突、计划被打断、连续不顺的时候。', practice: p);
    case '现实接纳':
    case '混乱中的恢复':
      return HappinessConceptLens(
        definition: '不是等环境理想了再恢复，而是在现实已经乱掉时，仍把自己慢慢拉回来。',
        experience: '你会很想立刻补偿式硬冲，但真正的恢复先来自承认“现在就是乱”。',
        realWorld: '常见在迟到、孩子/家庭打断、工作堆叠、计划被破坏时。',
        practice: '今天一旦节奏乱掉，先暂停半分钟，承认现实负荷，再决定只做下一件最重要的事。',
      );
    case '过程转向':
    case '结果契合':
    case '过程契合':
      return HappinessConceptLens(
        definition: '不只问“我要不要这个结果”，还要问“我喜不喜欢、适不适合走向它的过程”。',
        experience: '你可能很想要一个结果，但每天走向它的方式让你持续耗竭。',
        realWorld: '常见在专业选择、工作选择、升学、创业、长期项目里。',
        practice: '给一件重要事情分别打分：结果吸引力多少，过程契合度多少。然后考虑怎么调高过程分。',
      );
    case 'job':
    case 'career':
    case 'calling':
      final def = concept == 'job'
          ? '把工作主要当成赚钱和完成任务。'
          : concept == 'career'
              ? '把工作主要当成晋升、地位和往上走。'
              : '把工作主要当成使命、召唤和自我实现。';
      final exp = concept == 'job'
          ? '动力更多来自工资、下班、假期。'
          : concept == 'career'
              ? '动力更多来自下一个头衔、下一次晋升。'
              : '动力更多来自事情本身的意义与投入。';
      final prac = concept == 'job'
          ? '写一句你当前工作里最强的“差事视角”是什么。'
          : concept == 'career'
              ? '写一句你当前最常追逐的“下一站”是什么。'
              : '写一句你当前工作里最像使命感的一部分是什么。';
      return HappinessConceptLens(definition: def, experience: exp, realWorld: '同一份工作可能同时混着三种成分，但你通常会更偏其中一种。', practice: prac);
    case '动机结构':
    case '期待结构':
    case '时间指向':
      return HappinessConceptLens(
        definition: '它们帮助你识别：到底是什么在推着你做事，你在期待什么，以及你的心理总是活在今天还是下一站。',
        experience: '很多疲惫不是因为事多，而是因为驱动力长期是外推、比较和延后幸福。',
        realWorld: '常见在职场、学习、升迁、长期努力中。',
        practice: '回顾最近一周，把你最常见的驱动力写出来，再看它让你更有生命力还是更空。',
      );
    case '整体意义':
    case '局部枯燥':
      return HappinessConceptLens(
        definition: '有 calling 的事，也会有重复、枯燥、需要硬做的部分；关键是整体是否值得。',
        experience: '你会对大方向有热情，但对某些重复步骤仍会烦、累、想逃。',
        realWorld: '常见在教学、写作、科研、创业、带团队、照顾家庭里。',
        practice: '挑一件你明知重要但局部很烦的事，写出“为什么仍值得我做这一段枯燥”。',
      );
    case '意义建构':
    case '重新解释':
      return HappinessConceptLens(
        definition: '意义不是凭空美化，而是把原本存在但平时看不见的价值、连接和贡献重新看见。',
        experience: '当你只盯任务时会很空；当你看到它服务了谁，内心会重新接上电。',
        realWorld: '常见在日常工作、服务型岗位、重复性劳动里。',
        practice: '把你当前最琐碎的一项工作，用“它在服务谁、支持什么”重写一遍。',
      );
    case '价值发现':
    case '贡献视角':
      return HappinessConceptLens(
        definition: '不是给自己编神圣意义，而是看到自己在更大链条里真实的功能和贡献。',
        experience: '当你看见这条链，你会更不容易把自己看成无意义的小齿轮。',
        realWorld: '常见在投行、运营、后勤、支持岗、服务岗等容易被看轻的工作里。',
        practice: '写下你的一项工作具体在支持谁、避免了什么、创造了什么。',
      );
    case 'VIA':
    case '品格优势':
    case '过程优势':
      return HappinessConceptLens(
        definition: 'VIA 关注的是你身上那些更自然、更有生命力、也更有道德价值的优势，并把它们用到过程里。',
        experience: '当你在用自己的优势时，通常会更投入、更自然、更有活力。',
        realWorld: '常见在学习、组织、表达、帮助别人、探索、创造中。',
        practice: '今天挑一个你熟悉的优势，让它直接参与一件现实任务，而不是只在测评里看一眼。',
      );
    case '活力感':
    case '真实性':
    case '真实自我':
      return HappinessConceptLens(
        definition: '真正的我，常常出现在你最有活力、最自然、最像自己、不用演的时候。',
        experience: '你会明显感觉“我在这里是活的”，而不是硬撑或表演。',
        realWorld: '常见在讲述、组织、创作、学习、帮助别人、解决问题等具体活动中。',
        practice: '今天记录一个“这才是我”的瞬间，并写下当时你在做什么、怎么做。',
      );
    case '优势迁移':
    case '优势介入':
    case '问题解决':
      return HappinessConceptLens(
        definition: '优势不是标签，而是解决问题时能调动的工具。关键不是知道它，而是用它。',
        experience: '以前你可能只盯着问题本身；优势迁移会让你开始问“我身上哪种力量可以上场”。',
        realWorld: '常见在焦虑、关系紧张、回避、决策困难、学习困难里。',
        practice: '选一个当前问题，再选一个你最可信的优势，写下它今天怎样具体介入。',
      );
    default:
      return HappinessConceptLens(
        definition: '“$concept”是本单元中的关键概念，需放回 ${unit.title} 这一段的语境里理解：它不是抽象名词，而是课程想让你在真实生活中能识别和练习的内容。',
        experience: '当这个概念在你身上发生时，通常会先出现在自动想法里，然后传到身体，再体现在拖、躲、硬撑、过控或失望上。请结合本单元原文找它在你身上的样子。',
        realWorld: '它更可能出现在 ${unit.lifeCases.take(2).join('；')} 这样的情境中。请不要只记概念名字，要去认场景。',
        practice: '把本单元默认行动“${unit.defaultActionTitle}”压缩成今天能完成的一步，并在完成后记录事实。',
      );
  }
}

HappinessBehaviorSpec behaviorSpecFor(HappinessUnit unit) {
  final Map<String, HappinessBehaviorSpec> specs = <String, HappinessBehaviorSpec>{
    'L14-1': const HappinessBehaviorSpec(trigger: '开始做一件还不熟、可能会笨拙的新动作时。', thought: '如果我一开始就做不好，是不是说明我不适合。', body: '紧、怕丢脸、想先回去再准备。', oldPattern: '为了不出错而推迟开始，或者做砸后马上否定自己。', newPattern: '承认这本来就是学习区，先做出第一份样本。', fact: '记录我今天具体试了什么、卡在哪里、下次要改哪一点。'),
    'L14-2': const HappinessBehaviorSpec(trigger: '需要发言、表达需求、主动联系或露脸时。', thought: '万一别人觉得我很蠢/很烦怎么办。', body: '喉咙紧、胸口缩、想撤回。', oldPattern: '沉默、拖延、装没这回事。', newPattern: '先在低风险场景里说出一句真实的话。', fact: '记录我说了什么、对方真实反应是什么，而不是只脑补评价。'),
    'L14-3': const HappinessBehaviorSpec(trigger: '一想到有风险、有拒绝可能、有不确定性的时候。', thought: '这要是出问题就全完了。', body: '心急、发紧、脑中快速放大。', oldPattern: '越想越怕，最后不做。', newPattern: '把最坏情况写出来，再评估可承受性和学习空间。', fact: '记录最坏情况是否真的发生，以及真实后果有多大。'),
    'L14-4': const HappinessBehaviorSpec(trigger: '经历一次明显挫败时。', thought: '这一回合输了，说明我这条路不行。', body: '泄气、塌下来、很想给自己定性。', oldPattern: '用一次失利给整个人生下结论。', newPattern: '把这次放回长期尺度，看它逼我长出了什么。', fact: '记录这次失败后我更清楚了什么、更会了什么。'),
    'L14-5': const HappinessBehaviorSpec(trigger: '团队或关系里出现错误、失误、判断偏差时。', thought: '有人要被责备/我得赶紧自证不是我。', body: '警觉、防御、想甩锅或隐藏。', oldPattern: '责备、羞辱、回避复盘。', newPattern: '把错转成复盘对象：发生了什么、学到了什么、如何不重复。', fact: '记录问题机制，而不是只记录谁错了。'),
    'L14-6': const HappinessBehaviorSpec(trigger: '想到一件需要多次尝试才会有结果的事情。', thought: '我应该一次就有感觉、一次就有效。', body: '嫌麻烦、怕连续失败。', oldPattern: '样本太少就提前放弃。', newPattern: '先追踪尝试次数和上场密度。', fact: '记录本周我到底试了几次，而不是只记录成没成。'),
    'L15-6': const HappinessBehaviorSpec(trigger: '进展不顺、退步、绕路、计划被打断的时候。', thought: '怎么不是一路顺着上去？是不是我不行。', body: '烦躁、羞耻、急着把曲线掰回直线。', oldPattern: '把波动解释成失败，开始过度控制或彻底放弃。', newPattern: '承认成长是螺旋线，把这次挫折命名成一个练习节点。', fact: '记录这次波动属于什么：退步、绕路、重练还是校准。'),
    'L15-7': const HappinessBehaviorSpec(trigger: '被看见不足、收到意见、事情没完全达标时。', thought: '我要么完美，要么就是不够好。', body: '全身紧，想解释或想自责。', oldPattern: '防御、只看缺失、全有或全无。', newPattern: '先识别自己掉进的是哪一种模式，再做最小修正。', fact: '记录今天最常出现的是哪一种完美主义特征。'),
    'L15-10': const HappinessBehaviorSpec(trigger: '伴侣/朋友/家人没有按我期待回应时。', thought: '如果连这都做不到，说明他/她不够在乎。', body: '失望、紧绷、冷下来或想攻击。', oldPattern: '理想化后失望，失望后防御或拉远。', newPattern: '把失望具体说出来，练习修复而不是判定关系。', fact: '记录冲突中的具体事件和需求，而不是给人整体下结论。'),
    'L15-18': const HappinessBehaviorSpec(trigger: '要做一件让我怕评价、怕拒绝、怕出丑的事时。', thought: '等我再准备好一点再去吧。', body: '紧、拖、想找更安全的理由。', oldPattern: '一直停在准备和分析里。', newPattern: '做一个低阶暴露动作，让行为先发生。', fact: '记录我到底有没有上场，而不是只记录上场前有多害怕。'),
    'L15-20': const HappinessBehaviorSpec(trigger: '我做错、没做好、没达到自己标准的时候。', thought: '你怎么这么差，这都做不好。', body: '往里缩、沉重、羞耻。', oldPattern: '对自己说远比对别人残酷的话。', newPattern: '把内在对话改成会对朋友说的话。', fact: '记录那句责骂原话，以及我改写后的版本。'),
    'L15-22': const HappinessBehaviorSpec(trigger: '混乱、失手、尴尬、被打断、情绪翻上来的时候。', thought: '我现在这样太差了，事情已经全乱了。', body: '慌、乱、急、想立刻补偿。', oldPattern: '先攻击自己，再硬冲。', newPattern: '先走 Three Ps：允许、找一点学习、拉开视角。', fact: '记录我在哪个 P 上最卡、哪个 P 最帮到我。'),
    'L16-2': const HappinessBehaviorSpec(trigger: '我在坚持一个重要目标，但越来越累越来越空时。', thought: '只要结果值，过程难受也得忍。', body: '持续耗竭、机械推进。', oldPattern: '把幸福全部押后给未来结果。', newPattern: '同时评估结果契合和过程契合。', fact: '记录这件事的结果分和过程分分别是多少。'),
    'L16-3': const HappinessBehaviorSpec(trigger: '谈到工作、学习或一项长期投入时。', thought: '我现在到底是在熬、在爬，还是在活一件真正想做的事。', body: '可能是麻木、也可能是兴奋。', oldPattern: '混在一起，不分自己的主要驱动力。', newPattern: '区分 job / career / calling，再做小调整。', fact: '记录我最近做事主要更偏哪一种取向。'),
    'L16-8': const HappinessBehaviorSpec(trigger: '面对一个具体问题，不知道从哪里入手时。', thought: '我又卡住了，我是不是不行。', body: '容易陷在问题里打转。', oldPattern: '只盯问题本身，不调动自身优势。', newPattern: '先问哪个优势最适合上场。', fact: '记录今天我具体用了哪个优势，它怎样帮了问题。'),
  };
  return specs[unit.id] ?? HappinessBehaviorSpec(
    trigger: '当你在 ${unit.title} 对应的现实情境里遇到压力、评价、失败或不确定性时。',
    thought: _defaultThought(unit),
    body: _defaultBody(unit),
    oldPattern: _defaultOld(unit),
    newPattern: '把本单元默认行动“${unit.defaultActionTitle}”当成新路径的第一步。',
    fact: '记录：发生了什么、我做了什么、结果如何、它和本单元哪个概念最相关。',
  );
}

String _defaultThought(HappinessUnit unit) {
  if (unit.tags.contains('完美主义')) return '如果这一步不够好，就说明我不够好。';
  if (unit.tags.contains('失败')) return '只要有失败风险，我最好先别上场。';
  if (unit.tags.contains('calling') || unit.tags.contains('意义')) return '如果现在没有感觉到意义，是不是这件事就不值得。';
  return '如果这件事不顺，别人和我自己会怎么看我？';
}

String _defaultBody(HappinessUnit unit) {
  if (unit.tags.contains('关系')) return '心里发紧，想防御、解释、退开，或者立刻要求对方修正。';
  if (unit.tags.contains('过程') || unit.tags.contains('意义')) return '不一定是急，更多是空、钝、机械和耗。';
  return '身体会先紧起来，想拖、想躲、想先控制住再说。';
}

String _defaultOld(HappinessUnit unit) {
  if (unit.tags.contains('完美主义')) return '过度控制、迟迟不提交、只盯不足，或者干脆拖着不动。';
  if (unit.tags.contains('失败')) return '为了不失败而不尝试，或一有偏差就给自己下很重的定义。';
  if (unit.tags.contains('关系')) return '理想化、失望、防御、封闭或要求对方立刻完美修正。';
  return '停在脑内分析里，不真正进入现实行动。';
}


String conceptConnotationFor(HappinessUnit unit, String concept) {
  final String c = concept.trim();
  switch ('${unit.id}::$c') {
    case 'L15-6::直线思维':
      return '在这一段里，它的内涵不是“喜欢效率”，而是默认成长必须一路顺、一偏离就等于失败。它把波动误解成价值危机。';
    case 'L15-6::螺旋成长':
      return '在这一段里，它的内涵是：成长允许回撤、重练、反复碰到旧问题，但整体仍可能在往前。重点不是直不直，而是有没有继续学习。';
    case 'L15-6::卓越':
      return '在这一段里，它的内涵是：仍然认真、仍然高要求，但不再要求每一步都零误差；卓越和现实成长规律是相容的。';
    case 'L14-3::灾难化':
      return '在这一段里，它的内涵是：把模糊的不顺，自动放大成人生级威胁，使人无法看到真实后果与应对空间。';
    case 'L15-22::Permission':
      return '在这一段里，它的内涵是：先允许自己是人，允许此刻乱、难、慌，而不是先追加一层自我攻击。';
    case 'L15-22::Positive':
      return '在这一段里，它的内涵是：不否认痛苦，同时主动寻找一点可学习、可转化的部分。';
    case 'L15-22::Perspective':
      return '在这一段里，它的内涵是：把注意力从眼前被放大的片刻，拉回更长的时间尺度与更大的世界。';
    default:
      return '在本段里，“$c”的内涵是：${conceptLensFor(unit, concept).definition}';
  }
}

String conceptExtensionFor(HappinessUnit unit, String concept) {
  final String c = concept.trim();
  switch ('${unit.id}::$c') {
    case 'L15-6::直线思维':
      return '它的外延会扩展到学习计划、关系磨合、职业路径、自我成长等所有“本来就会有波动”的领域。';
    case 'L15-6::螺旋成长':
      return '它的外延会扩展到长期训练、关系修复、公开表达、领导力与自我修炼等需要反复上场的领域。';
    case 'L15-6::卓越':
      return '它的外延会扩展到项目交付、作品迭代、反馈吸收、关系经营等“可以持续变好”的现实任务。';
    case 'L14-3::灾难化':
      return '它的外延会扩展到面试、发言、提出需求、发消息、做决定等所有带不确定和评价风险的场景。';
    case 'L15-22::Permission':
    case 'L15-22::Positive':
    case 'L15-22::Perspective':
      return '它的外延会扩展到迟到、讲砸、计划被打乱、冲突、混乱、连续不顺等需要快速恢复的时刻。';
    default:
      final String life = unit.lifeCases.take(2).join('；');
      return life.isEmpty ? '它的外延会扩展到本单元相关的现实场景。' : '它的外延会扩展到这些现实场景：$life';
  }
}

String sceneFlowFor(HappinessUnit unit) {
  final spec = behaviorSpecFor(unit);
  return '进入${unit.scene}后，先把现实中的触发情境换成一个安全但接近真实的版本：${spec.trigger} 然后识别旧剧本“${spec.oldPattern}”，再练习新路径“${spec.newPattern}”，最后把它迁移成现实动作“${unit.defaultActionTitle}”。';
}


class HappinessActionPlanSpec {
  final String intro;
  final List<String> steps;
  final String successCriteria;
  final String fallbackAction;
  final String recordFocus;
  const HappinessActionPlanSpec({required this.intro, required this.steps, required this.successCriteria, required this.fallbackAction, required this.recordFocus});
}

List<String> conceptPracticeStepsFor(HappinessUnit unit, String concept) {
  final String key = '${unit.id}::${concept.trim()}';
  switch (key) {
    case 'L15-6::直线思维':
      return <String>[
        '选最近一次让你立刻觉得“这条路不对了”的具体事件，例如计划被打断、进展退步或被反馈卡住。',
        '把脑中原句原样写出来，例如“怎么不是一路顺上去”“是不是我不适合”。',
        '在纸上补一句替代解释：“这更像成长曲线里的一个波动，不是整条路作废。”',
        '给这次波动命名：绕路、停顿、回撤还是重练。',
        '只做一个 5 分钟恢复动作，例如重开文档、补一句说明、约下一次推进时间。',
      ];
    case 'L15-6::螺旋成长':
      return <String>[
        '找一件你觉得“怎么又回到这个问题”的真实事件。',
        '写下这次和上一次的不同：我现在比上次多了什么经验、信息或稳定度。',
        '把这次经历改写成一句螺旋句：“我不是回到原点，而是在这一层继续练。”',
        '补一个和“继续上场”一致的小动作，例如再次表达一次、再次练 10 分钟、再次发出一版。',
        '最后记录：这次回来，我和上一次已经哪里不一样。',
      ];
    case 'L15-6::卓越':
      return <String>[
        '选今天最重要的一件事，只选一件。',
        '先写“卓越版标准”：认真完成、允许调整、允许一处不完美存在。',
        '给自己一个明确时段，例如 15 或 25 分钟，只做这件事的关键部分。',
        '到点后立刻输出一个现实版本，而不是继续无限打磨。',
        '记录：我保持了哪一点认真，同时放下了哪一点完美执念。',
      ];
    case 'L14-2::评价焦虑':
      return <String>[
        '先选一个低风险但真实的场景，例如补一句观点、问一个问题、表达一个小需求。',
        '写下你最怕别人怎么想你，原句越真实越好。',
        '在心里先定标准：今天不是证明自己厉害，只是停止消失一次。',
        '按计划在那个场景里真实出现一次，说出那句话。',
        '结束后只记现实反馈，不按脑补评分。',
      ];
    case 'L15-20::自我慈悲':
    case 'L15-20::双重标准':
    case 'L15-20::白金法则':
      return <String>[
        '找今天一句最苛刻的自我责骂，原样写下来。',
        '想象是一个你很在乎的朋友犯了同样的错，你会怎么对他说。',
        '把原句改写成一句真实但不羞辱自己的话。',
        '读一遍改写后的句子，再去做一个该做的小动作，而不是停在安慰里。',
        '记录：语气改变后，我更愿意继续做什么。',
      ];
    case 'L16-8::VIA':
    case 'L16-8::品格优势':
    case 'L16-8::过程优势':
      return <String>[
        '先选今天最真实的一件任务，不要太大。',
        '从你熟悉的优势里挑一个最能帮这件事的，例如爱学习、真诚、组织力。',
        '写一句“我准备让这个优势通过什么具体动作进场”。',
        '立刻做出这个动作，例如查清一个问题、发起一次真实沟通、重新整理结构。',
        '结束后记录：这个优势有没有让过程更像我自己。',
      ];
    default:
      final spec = behaviorSpecFor(unit);
      final firstConcept = concept.trim().isEmpty ? unit.title : concept.trim();
      return <String>[
        '先选一个今天真实会发生的具体情境：${spec.trigger}',
        '把这个概念和当前情境连起来，写一句“我现在在练的是 $firstConcept，而不是证明我多完美”。',
        '把动作压缩成一个 5 到 15 分钟可完成的现实步骤。',
        '按时做一次，不反复修改，不等感觉完全对了才开始。',
        '做完只记录事实：发生了什么、我做了什么、结果怎样。',
      ];
  }
}

HappinessActionPlanSpec actionPlanFor(HappinessUnit unit, String level) {
  final spec = behaviorSpecFor(unit);
  final concept = unit.concepts.isEmpty ? unit.title : unit.concepts.first;
  switch ('${unit.id}::$level') {
    case 'L14-1::easy':
      return HappinessActionPlanSpec(
        intro: '把“允许自己在学习中失败”缩成一个今天就能完成的小样本。重点不是做得好，而是留下第一份可学习材料。',
        steps: <String>[
          '选一个你还不熟练的小动作，例如开口问一个问题、录一段练习、发一版粗稿。',
          '在开始前先写一句提醒：“我今天不是来证明自己成熟，而是来留下一个样本。”',
          '给自己一个很短的时间上限，例如 5 分钟，到点必须完成一次样本。',
          '完成后只写两行：哪里最生涩；下次最值得微调的一步是什么。',
        ],
        successCriteria: '你真的留下了一份样本，而不是继续停在准备阶段。',
        fallbackAction: '如果样本还是太大，就只做一个更小的切片，例如只说一句、只写三句、只练一分钟。',
        recordFocus: '记录“我学到了什么”而不是“我看起来够不够好”。',
      );
    case 'L14-1::standard':
      return HappinessActionPlanSpec(
        intro: '让失败真正作为学习反馈进入一次现实训练，而不是训练一遇到生涩就停止。',
        steps: <String>[
          '选一件你正在学的新东西，限定今天只推进一个小模块。',
          '先做一次，不允许边做边过度修正。',
          '做完后写下三个点：哪里不会；哪里比我想象中好一点；下一轮先修哪一处。',
          '按这三个点立刻做第二轮的最小修正，再次输出一次。',
          '最后记录：我不是避免失败，而是在利用失败训练。',
        ],
        successCriteria: '你至少完成了一轮“做—看偏差—改一点—再做”。',
        fallbackAction: '如果第二轮太大，就先只保留第一轮样本和三点反馈。',
        recordFocus: '记录哪一处偏差最有信息量，而不是整体验收自己。',
      );
    case 'L14-1::stretch':
      return HappinessActionPlanSpec(
        intro: '把“允许失败”带进一个更真实、会被看见的场景里，练习边紧张边继续出现。',
        steps: <String>[
          '选一个稍微会被看见的小场景，例如向人展示一版初稿、开口练一小段表达。',
          '开始前先写一句：“今天的目标不是成熟，而是让我和现实反馈接触一次。”',
          '按计划输出，不在最后一刻临时撤回。',
          '得到反馈后先不解释，只记三条事实。',
          '最后写一句：这次失败或生涩最值得我下次继续练哪一点。',
        ],
        successCriteria: '你让一个还不成熟的版本进入了现实，而不是继续藏在准备里。',
        fallbackAction: '先把公开度降一档，例如先发给一个安全对象。',
        recordFocus: '记录真实反馈和自己最初脑补之间的差距。',
      );
    case 'L14-2::easy':
      return HappinessActionPlanSpec(
        intro: '练一次低风险的真实出现，不解决所有评价焦虑，只停止一次自动消失。',
        steps: <String>[
          '先选一个今天真实会发生、但风险较低的场景。',
          '写下你最怕别人怎么看你，只写一句。',
          '把今天动作限定成一句话，例如补一个观点、问一个问题、说一个小需求。',
          '在那个场景里真的说出来。',
          '结束后只记录：我说了什么，对方真实反应是什么。',
        ],
        successCriteria: '你在一个真实场景里出现了一次。',
        fallbackAction: '如果公开说太难，就先发文字版给一个安全对象。',
        recordFocus: '记录别人真实的表情、回复和结果，而不是只记录自己的脑补。',
      );
    case 'L14-2::standard':
      return HappinessActionPlanSpec(
        intro: '把评价焦虑从脑补拉回现实证据，再做一次小暴露。',
        steps: <String>[
          '选一个你平时最容易沉默的情境类型，例如会议、群聊、面对面沟通。',
          '写两列：我脑补别人会怎么想 / 现实里我真正会做什么。',
          '提前准备一句你要说的话，不再临场无限修改。',
          '进入场景后按原句说出，不追求表现完美。',
          '结束后对照：脑补和现实有多大差距。',
        ],
        successCriteria: '你完成了一次带轻微评价风险的真实表达。',
        fallbackAction: '先在更安全的同类场景里做一版低暴露练习。',
        recordFocus: '重点记录“我担心的评价”与“实际发生的反馈”之间的差距。',
      );
    case 'L14-2::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更接近你真实回避主题的场景里出现一次，并承受那一点被看见的不适。',
        steps: <String>[
          '选一个你确实会想躲的场景，例如向上提问、主动请求、表达不同意见。',
          '把要说的话提前写成两句以内，避免临场被完美主义拉走。',
          '进入现场后在前半段就说出，不拖到最后。',
          '如果紧张上来，只提醒自己：今天目标是出现，不是赢。',
          '结束后记录：最难的是哪一秒，我是怎么撑过去的。',
        ],
        successCriteria: '你在更贴近真实回避主题的场景里，没有再次消失。',
        fallbackAction: '降低对象或场景难度，但保留“真实出现”这个核心。',
        recordFocus: '记录最关键的触发点和你没有退回去的那个动作。',
      );

    case 'L14-4::easy':
      return HappinessActionPlanSpec(
        intro: '先把一次失利从“我不行”改写成“这是长线中的一个节点”。',
        steps: <String>[
          '选最近一次让你明显失望的小失利，只写一件具体事。',
          '写下你最自动的一句结论，例如“我是不是不适合”。',
          '再写一句长期尺度改写：“三年后看，这更像一个节点而不是终局。”',
          '补一行：这次被逼出来的新能力可能是什么。',
        ],
        successCriteria: '你完成了一次从短线打击到长线节点的改写。',
        fallbackAction: '如果太难，就先只写“旧结论一句 + 长期改写一句”。',
        recordFocus: '记录这次失利逼你更清楚了什么，而不是只记录受伤感。',
      );
    case 'L14-4::standard':
      return HappinessActionPlanSpec(
        intro: '把一次真实失利放回长期时间线，并从中提炼一个继续上场的动作。',
        steps: <String>[
          '选一个你还在反复想的失利事件。',
          '写三列：当时发生了什么 / 我原来怎么定义自己 / 如果放回长期尺度我会怎么定义它。',
          '再写一条这次逼你增长的能力，例如更会准备、更会求助、更会判断方向。',
          '把这条能力翻译成一个今天就能做的小动作，并执行它。',
          '执行后记录：这次我是在恢复长期视角，还是仍在用单次结果判自己。',
        ],
        successCriteria: '你不仅改写了失利，还做了一个沿长期成长继续上场的动作。',
        fallbackAction: '先只做表格与能力提炼，动作缩到 5 分钟版本。',
        recordFocus: '记录“节点后的下一步”而不是只记录“节点有多痛”。',
      );
    case 'L14-4::stretch':
      return HappinessActionPlanSpec(
        intro: '把长期尺度带进一个你现在仍然害怕再次失败的主题里。',
        steps: <String>[
          '选一个你因为过去失利而明显缩手的主题。',
          '写一句：如果我继续让那次失利定义我，我接下来会怎么缩。',
          '再写一句：如果把它当成长节点，我现在最值得再次上场的一步是什么。',
          '今天就做这一步，哪怕只是一个半公开、小范围版本。',
          '之后记录：再上场时我最怕什么，它真的如我想象那样发生了吗。',
        ],
        successCriteria: '你让长期尺度真正改变了一次现实选择。',
        fallbackAction: '把再次上场的公开度降一档，但保留“再次上场”这个核心。',
        recordFocus: '记录恐惧和现实结果之间的差距。',
      );
    case 'L14-5::easy':
      return HappinessActionPlanSpec(
        intro: '把一次错误从“谁该负责”改写成“我能学到什么”。',
        steps: <String>[
          '选一个最近的小错误，不需要很大。',
          '先写一句你最想责怪谁或最想责怪自己的话。',
          '再写三行：发生了什么 / 学到了什么 / 下次怎么减少重复。',
          '保留这三行，作为今天的复盘样本。',
        ],
        successCriteria: '你把一个错误至少一次转成了学习材料。',
        fallbackAction: '如果三行太多，就只写“发生了什么 + 学到了什么”。',
        recordFocus: '记录机制问题，不做人格羞辱。',
      );
    case 'L14-5::standard':
      return HappinessActionPlanSpec(
        intro: '练一次“责任与学习同时保留”的错误复盘。',
        steps: <String>[
          '选一个最近确实造成后果的错误。',
          '写清楚：我在其中承担什么责任。',
          '再写清楚：这个错误暴露了哪一个系统、流程或准备漏洞。',
          '给这个漏洞设计一个最小修正动作，并在今天落实。',
          '最后记录：我有没有只停在责备，还是把责任推进成了改进。',
        ],
        successCriteria: '你既没有逃避责任，也没有停在归责。',
        fallbackAction: '如果修正动作太大，就先定义提醒、模板或一条新规则。',
        recordFocus: '记录“责任之后的修正动作”有没有发生。',
      );
    case 'L14-5::stretch':
      return HappinessActionPlanSpec(
        intro: '把“试错文化”带进一个真实互动场景，而不是只在脑内理解。',
        steps: <String>[
          '找一个你需要和别人讨论错误、失误或卡点的小场景。',
          '开头先描述事实，不先找人背锅。',
          '再补一句“这件事让我学到的是……”。',
          '最后给出一个下次更稳的机制建议。',
          '结束后记录：对话是更像归责，还是更像共同复盘。',
        ],
        successCriteria: '你在一个真实对话里实践了成长型反馈。',
        fallbackAction: '先把这段对话写成草稿，发给一个安全对象或先口头练一遍。',
        recordFocus: '记录这次沟通有没有把错误转成学习和机制。',
      );
    case 'L14-6::easy':
      return HappinessActionPlanSpec(
        intro: '先用“尝试配额”取代“单次成败”。',
        steps: <String>[
          '选一个你一直想做但老是退缩的小主题。',
          '给自己设一个本周尝试配额，例如 3 次。',
          '今天先完成其中 1 次最小版本。',
          '完成后只记录：这次上场了没有，而不是成没成。',
        ],
        successCriteria: '你完成了第一笔样本，而不是继续等“更确定的时候”。',
        fallbackAction: '把配额改成 1 次，但今天必须做。',
        recordFocus: '记录尝试次数，不做人格评判。',
      );
    case 'L14-6::standard':
      return HappinessActionPlanSpec(
        intro: '把注意力从“这次有没有赢”转到“我到底试了多少次、看到了什么模式”。',
        steps: <String>[
          '选一个你常因单次结果而放弃的主题。',
          '建立一个简单记录表：日期 / 尝试动作 / 结果 / 学到什么。',
          '今天先做一次真实尝试并填一行。',
          '做完后补一句：我要把样本积累到多少次再下结论。',
          '到晚上再看这次，不评价人格，只看模式。',
        ],
        successCriteria: '你开始用样本量思维替代单次成败思维。',
        fallbackAction: '如果表格太多，就先在备忘录写一行最小记录。',
        recordFocus: '记录这次尝试提供了什么信息，而不是它有多丢脸。',
      );
    case 'L14-6::stretch':
      return HappinessActionPlanSpec(
        intro: '把“提高失败率”真正带进一个你平时过度保护自己的主题。',
        steps: <String>[
          '选一个你想提高成功率但一直样本太少的主题，例如请求、投稿、表达、邀约。',
          '设一个小周期配额，例如接下来 7 天做 5 次。',
          '今天完成其中一次，并明确写下这是配额中的第几次。',
          '做完后不要立即下能力结论，只补一条下次微调。',
          '在记录中保留“我正在练的是尝试密度，不是一次证明自己”。',
        ],
        successCriteria: '你开始用密度训练而不是单次成败管理自己。',
        fallbackAction: '降低难度但保留次数，例如把公开请求改成小范围请求。',
        recordFocus: '记录本周配额推进情况和共通卡点。',
      );
    case 'L15-1::easy':
      return HappinessActionPlanSpec(
        intro: '练一次允许小偏差存在，同时不停止推进。',
        steps: <String>[
          '选一件今天要做的小任务。',
          '提前定义一条“允许存在的小偏差”，例如一处措辞不完美、一点小迟滞。',
          '完成任务时不要为了这条小偏差反复停下来。',
          '做完记录：我到底修的是问题，还是在掩盖不完美痕迹。',
        ],
        successCriteria: '你允许一处小偏差存在，并仍完成了事情。',
        fallbackAction: '把偏差再缩小一半，只练最容易承受的那一点。',
        recordFocus: '记录“我继续推进了”而不是“我有没有完全无误”。',
      );
    case 'L15-1::standard':
      return HappinessActionPlanSpec(
        intro: '把“不完美地开始”带进一个稍微会被看见的现实动作。',
        steps: <String>[
          '选一个今天会被别人看到的小输出，例如一条消息、一段说明、一版文稿。',
          '开始前写一句：“今天我允许一个小瑕疵存在，但不为它过度补偿。”',
          '按时输出，不临时为了一个小点无限修改。',
          '输出后只修真正影响沟通或结果的部分。',
          '记录：哪一刻我最想回去掩盖不完美，我有没有继续推进。',
        ],
        successCriteria: '你没有让小偏差夺走整个推进节奏。',
        fallbackAction: '先把公开度降一档，保留“按时输出”。',
        recordFocus: '记录“掩盖冲动”出现的时刻和你如何没有跟着走。',
      );
    case 'L15-1::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更贴近形象焦虑的场景里，练习“允许一处不完美存在并继续上场”。',
        steps: <String>[
          '选一个你特别想保持形象完整的场景。',
          '提前定义：今天哪一处小偏差如果出现，我不会立刻做过度补偿。',
          '进入场景后只处理真正影响核心结果的问题。',
          '结束后不做长时间自我审判，只写两条事实和一条学习。',
          '把“我仍然继续上场了”保存为今天的核心记录。',
        ],
        successCriteria: '你在更贴形象主题的场景里，仍允许小偏差存在。',
        fallbackAction: '把场景难度降一级，但保留“不做过度补偿”。',
        recordFocus: '记录哪处小偏差并没有造成你想象中的巨大后果。',
      );
    case 'L15-2::easy':
      return HappinessActionPlanSpec(
        intro: '做一次允许笨拙的练习，而不是要求第一次就像熟手。',
        steps: <String>[
          '选一个你想变好的技能切片。',
          '给自己 5 到 10 分钟，只做一轮生涩练习。',
          '不删除、不重来，保留这次笨拙痕迹。',
          '写一句：这不是证明我差，而是在训练区。',
        ],
        successCriteria: '你留下了一次笨拙练习，而不是再次躲开。',
        fallbackAction: '把练习再切小，只保留 1 分钟样本。',
        recordFocus: '记录生涩点和比想象稍微顺一点的地方。',
      );
    case 'L15-2::standard':
      return HappinessActionPlanSpec(
        intro: '让“不够好”真正变成一轮练习的原材料。',
        steps: <String>[
          '做一轮你尚不熟练的任务。',
          '做完后列三点：哪里不顺、哪里有一点点进步、下一轮先改哪一点。',
          '立刻再做第二轮，只改这一点。',
          '第二轮结束后，对比两轮差异。',
          '记录：成长是不是更像螺旋，而不是一下子到位。',
        ],
        successCriteria: '你完成了一轮具体练习，而不是只停在“我不够好”的感受里。',
        fallbackAction: '先只做第一轮和三点反馈。',
        recordFocus: '记录两轮之间最小但真实的变化。',
      );
    case 'L15-2::stretch':
      return HappinessActionPlanSpec(
        intro: '把“允许不够好练习”带进一个稍微会被看见的场景里。',
        steps: <String>[
          '选一个会被看到的小训练结果，例如一段表达、一版草稿、一次演示。',
          '提前提醒自己：今天目标是练习，不是展示成熟版本。',
          '按时发出或呈现这个练习结果。',
          '得到反应后先不羞耻收缩，只记事实。',
          '最后写一句：这次不够好具体让我知道下一轮该练什么。',
        ],
        successCriteria: '你让一个练习中的版本进入了现实世界。',
        fallbackAction: '先降低可见度，但仍让一个外部对象看见。',
        recordFocus: '记录别人真实看见了什么，而不是你脑内替他们下的结论。',
      );
    case 'L15-3::easy':
      return HappinessActionPlanSpec(
        intro: '先识别旧剧本又迁移到新场景里来了。',
        steps: <String>[
          '写出一个你最近换了环境却仍然熟悉痛苦的场景。',
          '补一句：我最常重复的旧剧本是什么。',
          '再写一句：这个剧本以前也出现过在哪里。',
          '最后给这个剧本起一个短名字。',
        ],
        successCriteria: '你把“环境问题”至少部分看见成了“模式迁移”。',
        fallbackAction: '如果太难，就先写“这个感觉我以前也有过”。',
        recordFocus: '记录旧剧本最像以前哪个场景。',
      );
    case 'L15-3::standard':
      return HappinessActionPlanSpec(
        intro: '识别旧剧本迁移后，再做一个不按旧剧本的小反动作。',
        steps: <String>[
          '先写出当前场景和旧剧本名字。',
          '补一句：旧剧本通常会让我怎么做。',
          '再写一句：如果不按旧剧本走，一个最小反动作是什么。',
          '今天就做这个小反动作。',
          '记录：识别模式后，我有没有真正改变一点行为。',
        ],
        successCriteria: '你不仅看见了旧模式，还做出了一个反方向动作。',
        fallbackAction: '把反动作缩到更小，例如只改变一个回应习惯。',
        recordFocus: '记录旧剧本最想接管的那一秒。',
      );
    case 'L15-3::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个真实重要的新环境里，阻止旧剧本再次完全接管。',
        steps: <String>[
          '选一个你现在最在意的新环境场景。',
          '写清旧剧本会怎么毁掉这个场景。',
          '提前定义一个反剧本动作，例如提早出现、少解释一次、先交一版、先说一句。',
          '进入场景时先完成这个反剧本动作。',
          '结束后记录：这次新环境里，我有没有稍微不是旧的自己。',
        ],
        successCriteria: '你在重要场景里打断了一次旧模式的自动接管。',
        fallbackAction: '先在低风险版同类场景练一次反剧本动作。',
        recordFocus: '记录新环境里最像旧环境的时刻和你的新反应。',
      );
    case 'L15-4::easy':
      return HappinessActionPlanSpec(
        intro: '先把一个目标从“必须完美”改写成“认真追求卓越”。',
        steps: <String>[
          '选一个当前重要目标。',
          '写下你原来带有完美主义色彩的版本。',
          '再改写成卓越版：保留认真和高度，但允许学习和偏差。',
          '今天按卓越版做一个小推进动作。',
        ],
        successCriteria: '你完成了一次目标语言和行动姿态的改写。',
        fallbackAction: '如果整目标太大，就先改写其中一个子任务。',
        recordFocus: '记录原目标里最强的控制成分是什么。',
      );
    case 'L15-4::standard':
      return HappinessActionPlanSpec(
        intro: '保留抱负，但放松“路径必须毫无偏差”的控制。',
        steps: <String>[
          '选一个你很在意、也容易逼自己的任务。',
          '写两列：我真正的抱负 / 我附加的完美主义要求。',
          '删掉一条完美主义要求，只保留抱负与关键标准。',
          '按这个新标准推进 15 到 25 分钟。',
          '结束后记录：少了一条控制要求，我是不是更能行动。',
        ],
        successCriteria: '你把 ambition 和完美主义拆开了一次。',
        fallbackAction: '先只删掉最不必要的一条控制要求。',
        recordFocus: '记录删掉哪条要求后，行动更顺了多少。',
      );
    case 'L15-4::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个高要求、会被看见的任务里，实践“高抱负但不零误差”的推进方式。',
        steps: <String>[
          '选一个你特别容易用完美主义保护 ambition 的任务。',
          '定义“卓越版标准”：关键部分认真完成，但允许非关键处不完美。',
          '给自己一个推进时段，到点后必须产出现实版本。',
          '如果中间出现偏差，不重新开局，只继续推进关键部分。',
          '结束后记录：真正帮到结果的是高度，还是控制。',
        ],
        successCriteria: '你在高标准任务里实践了一次“卓越而非完美”。',
        fallbackAction: '先用较小的公开任务做一版实验。',
        recordFocus: '记录哪些高标准是真必要，哪些只是防御。',
      );
    case 'L15-5::easy':
      return HappinessActionPlanSpec(
        intro: '先交一版，而不是继续把第一版关在抽屉里。',
        steps: <String>[
          '选一个今天能产出草稿的小内容。',
          '给自己一个 10 分钟上限。',
          '到点后停止修改，保留这版草稿。',
          '把它发给自己、存下来或发给一个安全对象。',
        ],
        successCriteria: '第一版真的离开了脑内，进入了现实。',
        fallbackAction: '把草稿范围再切小，例如只写开头或目录。',
        recordFocus: '记录你什么时候最想把它继续锁回抽屉。',
      );
    case 'L15-5::standard':
      return HappinessActionPlanSpec(
        intro: '练一次“先输出，再优化”，用现实反馈替代脑内完美。',
        steps: <String>[
          '选一个你已经拖了的初稿或输出。',
          '定义最多修改轮次，例如两轮。',
          '做完两轮后立刻发出，不允许第三轮再因为焦虑继续拖。',
          '发出后只记一条想优化的点，不重新整体否定。',
          '把这次发出保存为一个训练样本。',
        ],
        successCriteria: '你完成了一次有限修改后的真实输出。',
        fallbackAction: '先改成发给一个安全对象，但仍保留“限定轮次”。',
        recordFocus: '记录“发出前最后一刻”的回避冲动和你如何没有听它。',
      );
    case 'L15-5::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更贴真实评价风险的任务里，练“草稿意识 + 限定修改 + 按时输出”。',
        steps: <String>[
          '选一个你真的会因怕评价而拖延的输出。',
          '预先定义：最多修改几轮、几点前必须发出。',
          '执行修改时只动关键部分，不为了面子做无限润色。',
          '按时发出。',
          '发出后立即写下：现实反馈将比我脑内打分更重要。',
        ],
        successCriteria: '你在更真实的评价风险下完成了一次按时输出。',
        fallbackAction: '降低对象难度，但保留时间边界。',
        recordFocus: '记录限定轮次对你行动的帮助和痛点。',
      );
    case 'L15-8::easy':
      return HappinessActionPlanSpec(
        intro: '先练习在完成后停留两分钟，不马上逃向下一站。',
        steps: <String>[
          '选今天一件会完成的小事。',
          '完成后先不要立刻切换到下一件。',
          '用两分钟写三条：过程里我学到了什么、哪里比原来更稳、哪里有一点满足。',
          '再决定是否进入下一件事。',
        ],
        successCriteria: '你在完成后至少停留并整合了一次。',
        fallbackAction: '如果两分钟太长，就先写一条过程收获。',
        recordFocus: '记录自己是否第一反应就是冲向下一站。',
      );
    case 'L15-8::standard':
      return HappinessActionPlanSpec(
        intro: '把“松一口气”与“真正整合过程价值”区别开来。',
        steps: <String>[
          '选一个今天或最近刚完成的节点。',
          '写两列：我只是松了什么气 / 我真正得到了什么。',
          '从第二列里选一条，写成一句过程价值总结。',
          '在开始下一件事前，读一遍这句总结。',
          '晚上复盘时再看：我有没有只是又被下一站带走。',
        ],
        successCriteria: '你把完成后的体验从“解除压力”推进成了“整合收获”。',
        fallbackAction: '先只做两列，不要求立刻改变整个节奏。',
        recordFocus: '记录你真正得到的东西，而不是只记录完成本身。',
      );
    case 'L15-8::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你最容易“达成后立刻奔下一站”的主题上，练习过程整合。',
        steps: <String>[
          '选一个你特别容易追下一站的主题，例如工作节点、学习目标、健身指标。',
          '完成一个小节点后，强制留出 10 分钟不进入下一目标。',
          '写下：这一段过程里我最值得保留的做法、体验和学习。',
          '从中选一个点，明确下一轮继续保留。',
          '再开始下一站。',
        ],
        successCriteria: '你没有把每个达成点都变成通往下一焦虑点的跳板。',
        fallbackAction: '先把整合时间缩短到 3 分钟。',
        recordFocus: '记录停留是否让你更接近过程幸福，而不只是更会冲。',
      );
    case 'L15-9::easy':
      return HappinessActionPlanSpec(
        intro: '在一个容易全有或全无的地方，练一次“中间地带”。',
        steps: <String>[
          '选一个你容易走极端的小主题，例如饮食、任务、自律。',
          '提前定义今天的适度版本是什么。',
          '一旦出现一点偏差，不宣布整天作废，只回到适度版本。',
          '做完记录：我怎样阻止了“既然偏了那就全完”。',
        ],
        successCriteria: '你至少一次把自己从极端摆回了中间地带。',
        fallbackAction: '把适度版本再做得更小、更容易回来。',
        recordFocus: '记录偏差发生的那一刻，你是怎么没有一路滑到底的。',
      );
    case 'L15-9::standard':
      return HappinessActionPlanSpec(
        intro: '把“局部偏差”留在局部，而不是让它吞掉整件事。',
        steps: <String>[
          '选一个你最近最容易“破一点就全盘作废”的主题。',
          '写一句你的旧规则，例如“要么严格到底，要么算了”。',
          '改写成新规则：“偏一点时，我只做局部调整，不把整件事作废。”',
          '今天当偏差出现时，立刻执行一个局部调整动作。',
          '晚上记录：这次我有没有保住整体，而不是让它崩成全无。',
        ],
        successCriteria: '你完成了一次从极端规则到局部调整的转向。',
        fallbackAction: '先在低风险主题上做一次实验。',
        recordFocus: '记录局部调整动作具体是什么。',
      );
    case 'L15-9::stretch':
      return HappinessActionPlanSpec(
        intro: '把“适度”带进一个你最容易用极端来换安全感的主题。',
        steps: <String>[
          '选一个你最常全有或全无的高频主题。',
          '提前写出三条适度边界，例如做到 70% 也算完成。',
          '今天按适度边界推进，不再临时提高到完美标准。',
          '一旦偏差出现，按边界回调，而不是整段报废。',
          '记录：适度让我更松散了，还是反而更能持续。',
        ],
        successCriteria: '你在高频主题上练到了一次可持续的中间地带。',
        fallbackAction: '先在较低风险主题上验证适度边界。',
        recordFocus: '记录适度边界是否真实帮助你摆脱了节制—放纵摆动。',
      );
    case 'L15-13::easy':
      return HappinessActionPlanSpec(
        intro: '先把一次“夸聪明/夸结果”改成“夸努力/夸过程”。',
        steps: <String>[
          '回想今天一个你想肯定自己或别人的场景。',
          '写下你本来会怎么夸，例如“你好厉害”。',
          '改写成过程版，例如“你刚才真的有投入、有尝试、有坚持”。',
          '今天就用出这句过程版夸法。',
        ],
        successCriteria: '你真实使用了一次过程导向的反馈。',
        fallbackAction: '先在备忘录里练写三句过程版夸法。',
        recordFocus: '记录改写后，对方或你自己的感受有什么不同。',
      );
    case 'L15-13::standard':
      return HappinessActionPlanSpec(
        intro: '在一个真实评价场景中，练一次从结果导向反馈转向过程导向反馈。',
        steps: <String>[
          '选一个今天必然会评价自己或别人表现的场景。',
          '先写出你本来会夸的结果或人设。',
          '再补三条过程事实：用了哪些努力、策略、尝试、坚持。',
          '用过程事实来表达肯定。',
          '记录：评价方式改变后，压力感和学习感有没有变化。',
        ],
        successCriteria: '你在真实评价场景里使用了一次成长型反馈。',
        fallbackAction: '先从自我评价开始，而不是直接对他人使用。',
        recordFocus: '记录你最自然会滑回去的是哪种旧夸法。',
      );
    case 'L15-13::stretch':
      return HappinessActionPlanSpec(
        intro: '连续一周在固定场景里练过程导向反馈，观察它如何改变氛围和行动意愿。',
        steps: <String>[
          '选一个你高频会评价的对象或场景。',
          '提前准备 3 句不同的过程型反馈模板。',
          '接下来每次评价时至少使用其中一句。',
          '记录对方和你自己的反应。',
          '一周后回看：这种反馈是否更能支持继续练习。',
        ],
        successCriteria: '你把成长型反馈从一次练习推进成了稳定使用。',
        fallbackAction: '先连续三次而不是一周。',
        recordFocus: '记录过程型反馈是否减少了“必须完美才值得被肯定”的压力。',
      );
    case 'L15-15::easy':
      return HappinessActionPlanSpec(
        intro: '先把旧剧本点名，而不是让它继续匿名接管。',
        steps: <String>[
          '写下今天最熟悉的一个旧模式瞬间。',
          '给它起一个简短名字。',
          '补一句：它通常会把我带去哪里。',
          '今天一旦它再出现，就先在心里点名。',
        ],
        successCriteria: '你至少一次在剧本接管前看见了它。',
        fallbackAction: '事后补写也可以。',
        recordFocus: '记录最早识别到它的是哪一秒。',
      );
    case 'L15-15::standard':
      return HappinessActionPlanSpec(
        intro: '点名旧剧本后，立刻接一个小反动作。',
        steps: <String>[
          '找一个今天很可能再次启动旧剧本的场景。',
          '提前写下旧剧本名字和它会拉你去做的旧行为。',
          '再写一个最小反动作。',
          '场景到来时先点名，再立刻做反动作。',
          '复盘：看见它后，我是否真的少被它带走一点。',
        ],
        successCriteria: '你把觉察推进成了一次现实反应改变。',
        fallbackAction: '把反动作缩到只改变一句话或一个时间点。',
        recordFocus: '记录点名后身体有没有多一点空间。',
      );
    case 'L15-15::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个高频高强度场景里，阻断一次旧剧本的完整接管。',
        steps: <String>[
          '选一个最常把你拖回旧模式的高频场景。',
          '写清旧剧本的完整链条：触发—想法—旧行为。',
          '在链条最早节点插入一个反动作。',
          '今天实战一次。',
          '复盘：我阻断的是哪一环，它最想怎样拉回去。',
        ],
        successCriteria: '你在高频场景里拦住了一次完整接管。',
        fallbackAction: '先在低压力版同类场景练。',
        recordFocus: '记录剧本最有力的一环在哪里。',
      );
    case 'L15-16::easy':
      return HappinessActionPlanSpec(
        intro: '先奖励一次真实尝试，而不等结果完美。',
        steps: <String>[
          '回想今天一个你真的尝试过的点。',
          '写下你原来可能会因为结果一般而忽略它。',
          '补一句过程型肯定。',
          '把这句肯定保存到复盘里。',
        ],
        successCriteria: '你让一次尝试被看见，而不是只看结果。',
        fallbackAction: '如果没有大尝试，就找一个小出现动作。',
        recordFocus: '记录你今天哪一点本身就值得被强化。',
      );
    case 'L15-16::standard':
      return HappinessActionPlanSpec(
        intro: '用过程奖励把一次动作继续接到下一次，而不是停在结果判断。',
        steps: <String>[
          '选一个你正在练但结果还不稳定的主题。',
          '做一次真实动作。',
          '完成后写三条过程型奖励：我出现了、我坚持了、我修正了哪里。',
          '再立刻安排下一次更小一步。',
          '记录：过程奖励有没有提高我继续练的意愿。',
        ],
        successCriteria: '你把一次尝试连接到了下一次练习。',
        fallbackAction: '先只写一条过程奖励。',
        recordFocus: '记录什么样的奖励最能让你继续上场。',
      );
    case 'L15-16::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你总被结果绑架的主题上，连续几次练过程奖励。',
        steps: <String>[
          '选一个高频训练主题。',
          '接下来三次动作后都用同一模板做过程奖励。',
          '每次奖励后都安排一个更小的下一步。',
          '到第三次后回看：我是否更稳定愿意继续。',
          '总结哪种过程奖励最有效。',
        ],
        successCriteria: '你把过程奖励从一次练习推进成了习惯模板。',
        fallbackAction: '先连续两次。',
        recordFocus: '记录持续奖励是否减轻了你对结果的绑架。',
      );
    case 'L16-1::standard':
      return HappinessActionPlanSpec(
        intro: '把注意力从未来终点拉回今天的过程体验一次。',
        steps: <String>[
          '选一件你最近总在说“等到了再说”的事。',
          '写下你最常押后的那个结果。',
          '再写今天过程里一个值得被注意的点。',
          '做任务时至少一次停下来感觉这个过程点。',
          '晚上记录：过程感有没有被看见一点。',
        ],
        successCriteria: '你把幸福从未来拉回了一点今天的过程。',
        fallbackAction: '先只写结果执念和一个过程点。',
        recordFocus: '记录自己最自然会把意义全丢给未来的时刻。',
      );
    case 'L16-1::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个长期主题上，练习同时看终点和过程，而不让终点独占意义。',
        steps: <String>[
          '选一个长期目标。',
          '写两列：终点为什么重要 / 过程今天如何也有价值。',
          '今天做这个目标相关的一步，并在过程中刻意体验第二列。',
          '做完后记录：今天有没有哪一秒让我觉得“原来路上也有东西”。',
          '保留这个过程线索，作为下一轮继续练的入口。',
        ],
        successCriteria: '你在长期主题上练到了一次过程回收。',
        fallbackAction: '先在一个较小目标上实验。',
        recordFocus: '记录哪一个过程细节最能帮你把注意力拉回来。',
      );
    case 'L16-2::easy':
      return HappinessActionPlanSpec(
        intro: '先把结果分和过程分分开打一次。',
        steps: <String>[
          '选一件你当前在坚持的重要事情。',
          '分别给“结果吸引力”和“过程契合度”打分。',
          '写一句：我真正低的是哪一项。',
          '今天只调整一个过程细节。',
        ],
        successCriteria: '你至少一次把结果和过程拆开看了。',
        fallbackAction: '如果打分太抽象，就只写“我想不想要结果 / 我喜不喜欢这样做”。',
        recordFocus: '记录过程里最消耗你的那个细节。',
      );
    case 'L16-2::standard':
      return HappinessActionPlanSpec(
        intro: '把双维评估真正转成一次过程调整。',
        steps: <String>[
          '对一个任务分别写出结果吸引力和过程契合度。',
          '找出过程里最不契合的一步。',
          '设计一个更贴近自己的做法。',
          '今天就按新做法推进一次。',
          '记录：过程分有没有变化。',
        ],
        successCriteria: '你不只识别了过程失配，还调整了一次路径。',
        fallbackAction: '先只改一个小环节。',
        recordFocus: '记录调整前后，身体和情绪哪个更有变化。',
      );
    case 'L16-2::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个长期重要主题上，连续练结果契合与过程契合并重。',
        steps: <String>[
          '选一个长期主题。',
          '连续三天都做一次结果分/过程分记录。',
          '每天都微调一个过程细节。',
          '第三天后回看：哪些调整最有效。',
          '决定是否继续、调整还是换路。',
        ],
        successCriteria: '你把双维评估推进成了连续观察。',
        fallbackAction: '先连续两天。',
        recordFocus: '记录什么样的过程最像你自己。',
      );
    case 'L16-4::easy':
      return HappinessActionPlanSpec(
        intro: '先识别最近最常驱动你的那股力量。',
        steps: <String>[
          '回想最近一周一件重要工作。',
          '写下最主要驱动力：钱、评价、进展、意义、责任或别的。',
          '补一句：这股驱动力让我更像差事、事业还是召唤。',
          '今天做一个更贴真实价值的小动作。',
        ],
        successCriteria: '你识别了当前驱动力，并做了一个小修正。',
        fallbackAction: '先只完成驱动力识别。',
        recordFocus: '记录最常推着你走的是哪种力量。',
      );
    case 'L16-4::standard':
      return HappinessActionPlanSpec(
        intro: '把当前动力结构看清，再让行动更贴近你真正想要的方向。',
        steps: <String>[
          '选一个近期反复消耗你的任务。',
          '写两列：现在主要动力 / 我更希望由什么驱动。',
          '设计一个让后者稍微进入的动作。',
          '今天执行它。',
          '复盘：动力结构是否有一丝变化。',
        ],
        successCriteria: '你让动力不再只有惯性推着走。',
        fallbackAction: '先把理想驱动力只落在一个小动作上。',
        recordFocus: '记录哪个驱动力最容易把你带向空耗。',
      );
    case 'L16-4::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个高频工作主题里，主动把差事/事业逻辑往召唤逻辑拉近一点。',
        steps: <String>[
          '选一个你每天都会碰到的工作主题。',
          '写下它当前最像差事还是事业。',
          '再写一条如果更接近召唤，会增加什么具体行为。',
          '今天执行这个行为。',
          '记录：它有没有让你更感觉是在活，而不只是完成。',
        ],
        successCriteria: '你在高频主题里练到了一次取向微调。',
        fallbackAction: '先从低成本行为开始。',
        recordFocus: '记录召唤感进入时最先变化的是哪一部分。',
      );
    case 'L16-7::easy':
      return HappinessActionPlanSpec(
        intro: '先找出这件事真实存在的一条价值链。',
        steps: <String>[
          '选一件你最近只想成“就是为了钱/应付”的工作。',
          '写下它真实影响了谁。',
          '再写它支持了什么更大的系统。',
          '保留这两句，今天做这件事前先看一遍。',
        ],
        successCriteria: '你至少看见了一条原本就存在的价值链。',
        fallbackAction: '先只写“它帮助了谁”。',
        recordFocus: '记录看见价值链后，参与感是否有一点变化。',
      );
    case 'L16-7::standard':
      return HappinessActionPlanSpec(
        intro: '把“真实价值”从脑内说明推进成一个现实动作。',
        steps: <String>[
          '选一项当前重要工作。',
          '写三句真实价值说明，不拔高、不粉饰。',
          '从中选一句，翻成今天的一条具体行为。',
          '执行这条行为。',
          '复盘：价值视角是否改变了你的参与方式。',
        ],
        successCriteria: '你把价值发现转成了现实参与方式。',
        fallbackAction: '先只完成价值说明，不强求今天立刻大改。',
        recordFocus: '记录哪句价值说明最能真正打动你。',
      );
    case 'L16-7::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你长期只用功利逻辑理解的工作主题里，实践一次价值发现后的行动升级。',
        steps: <String>[
          '选一个你最容易只从收益看待的主题。',
          '写下功利版解释和价值版解释。',
          '设计一个只有在价值版视角下才会出现的行为。',
          '今天执行它。',
          '记录：这更像粉饰，还是让我更真实地投入了。',
        ],
        successCriteria: '你把价值发现推进成了可观察的新行为。',
        fallbackAction: '先选一个风险较低的小行为。',
        recordFocus: '记录你如何区分“真实价值”与“自我美化”。',
      );
    case 'L16-9::standard':
      return HappinessActionPlanSpec(
        intro: '捕捉一个“这才是我”的时刻，并把它拆成可重复的线索。',
        steps: <String>[
          '今天结束前回想一个最有活力的时刻。',
          '写下当时你在做什么、和谁在一起、用什么方式出现。',
          '补一句：这时最像我的部分是什么。',
          '明天刻意复制其中一个条件。',
          '记录复制后是否仍有同样活力感。',
        ],
        successCriteria: '你不只捕捉了活力时刻，还提炼了一个可重复线索。',
        fallbackAction: '先只完成活力时刻回忆。',
        recordFocus: '记录让你最像自己的条件是什么。',
      );
    case 'L16-9::stretch':
      return HappinessActionPlanSpec(
        intro: '连续一周追踪“这才是我”的时刻，找出稳定的真实性模式。',
        steps: <String>[
          '连续 3 到 7 天，每天记录一个最有活力时刻。',
          '每次都写：我在做什么、怎么做、为了什么。',
          '第三天后开始找重复出现的条件。',
          '把其中一个条件主动加到下一天安排里。',
          '一周后总结：什么最稳定地让我像真实的自己。',
        ],
        successCriteria: '你开始从偶发活力走向稳定识别自我。',
        fallbackAction: '先连续三天。',
        recordFocus: '记录重复出现的真实性线索，而不是只记录单次感受。',
      );

    case 'L15-11::standard':
      return HappinessActionPlanSpec(
        intro: '把“高压爆冲”改成一次可持续推进实验。',
        steps: <String>[
          '选一个你最近总想靠逼自己完成的任务。',
          '先写出你原来的爆冲版本会怎么做。',
          '再定义一个可持续版本：只做关键部分、只推进一个时段、保留恢复余地。',
          '按可持续版本推进 20 分钟。',
          '记录：今天更有效的是压力，还是节律。',
        ],
        successCriteria: '你完成了一次“强度下降但推进没有停”的实验。',
        fallbackAction: '先把时段缩短到 10 分钟。',
        recordFocus: '记录节律感有没有回来。',
      );
    case 'L15-11::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个高重要度任务上，练习不用高压也能保持表现。',
        steps: <String>[
          '选一个你最容易靠压力顶住的重要任务。',
          '预先定义今天只守住三件关键事，不做全覆盖冲刺。',
          '推进时一旦想全面补齐，就回到三件关键事。',
          '到点停止，不用过度透支换“看起来很拼”。',
          '复盘：可持续推进有没有比高压更稳。',
        ],
        successCriteria: '你在高重要度任务里也练到一次稳态推进。',
        fallbackAction: '先把任务公开度降一档。',
        recordFocus: '记录“保住节奏”是否比“短时更猛”更有帮助。',
      );
    case 'L15-12::standard':
      return HappinessActionPlanSpec(
        intro: '识别一个正在塑造你标准的外部模板，并把它拆回真实尺度。',
        steps: <String>[
          '选一个最近最容易触发你自我否定的外部模板。',
          '写下它暗示你的标准是什么。',
          '再写三句真实人类版本：现实里大多数人其实怎样。',
          '把今天一个动作按真实人类版本去做。',
          '记录：标准一松回真实，我更能行动了吗。',
        ],
        successCriteria: '你把一个外部模板从自动标准拉回了可见对象。',
        fallbackAction: '先只做“模板一句 + 真实版本一句”。',
        recordFocus: '记录模板对你最直接的影响是羞耻、焦虑还是比较。',
      );
    case 'L15-12::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你长期被模板绑住的主题上，练习按真实尺度行动。',
        steps: <String>[
          '选一个你最容易被模板驱动的高频主题。',
          '写出模板版标准和真实人类版标准。',
          '今天只按真实人类版标准推进。',
          '当内心又想加码时，提醒自己这是模板在发声。',
          '复盘：少了模板后，我更接近真实还是更放弃了。',
        ],
        successCriteria: '你在真实高频主题里完成了一次去模板化行动。',
        fallbackAction: '先在低风险版同类主题上练。',
        recordFocus: '记录你最难放下的是哪个模板要求。',
      );
    case 'L15-14::standard':
      return HappinessActionPlanSpec(
        intro: '练一次 20/80 推进，不再把所有部分都抬到同一优先级。',
        steps: <String>[
          '列出当前任务的全部子项。',
          '圈出最影响结果的两三项。',
          '今天只优先推进这几项，不为了次要部分反复补。',
          '到点后停止。',
          '记录：真正推动结果的是哪几项。',
        ],
        successCriteria: '你完成了一次优先级推进，而不是平均用力。',
        fallbackAction: '先只圈出一个最关键子项。',
        recordFocus: '记录你最想回去打磨但其实不关键的部分是什么。',
      );
    case 'L15-14::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个任务量很大的场景里，实践“关键推进优先于全面完美”。',
        steps: <String>[
          '选一个你最近最容易什么都想顾到的任务。',
          '提前定义今天只允许自己完成关键20%。',
          '推进过程中一旦想分神去修枝节，就回到关键20%。',
          '按时收工，不因为没顾到全部而继续拖。',
          '复盘：少顾 80% 是否真的毁了结果。',
        ],
        successCriteria: '你在复杂任务里完成了一次抓重点。',
        fallbackAction: '缩成一个较小任务再练。',
        recordFocus: '记录“没做的部分”是否真的像脑补中那么致命。',
      );
    case 'L15-17::standard':
      return HappinessActionPlanSpec(
        intro: '练一次“问题还在，但我仍行动”。',
        steps: <String>[
          '写下你最近反复出现的老问题。',
          '承认它今天很可能还会在。',
          '再写一句：即便如此，我今天仍要做的一步是什么。',
          '执行这一步。',
          '复盘：我有没有把“还没好”误当成“不能动”。',
        ],
        successCriteria: '你带着未解决的问题仍然做出了一步行动。',
        fallbackAction: '把这一步缩到 5 分钟。',
        recordFocus: '记录问题仍在时，你怎么没有完全停住。',
      );
    case 'L15-17::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你最想等“彻底好了再说”的主题上，练习边接纳边推进。',
        steps: <String>[
          '选一个你一直想等状态完全好再做的主题。',
          '写下那个“等好了再说”的条件。',
          '删除这个条件，换成“今天我先做的一步”。',
          '今天完成它。',
          '记录：问题没消失，但行动有没有发生。',
        ],
        successCriteria: '你不再把“未完全解决”当成暂停生活的理由。',
        fallbackAction: '先在低风险主题上练。',
        recordFocus: '记录接纳之后，行动阻力是否下降。',
      );
    case 'L15-19::standard':
      return HappinessActionPlanSpec(
        intro: '在行动前完整做一轮可视化 + 状态进入，再去现实里做。',
        steps: <String>[
          '选一个今天会让你紧张的现实动作。',
          '先闭眼 2 分钟，想象自己更稳地进入场景。',
          '再做 3 次呼吸，把注意力从结果拉回动作。',
          '按计划进入现实场景。',
          '复盘：状态切换前后，我的身体与想法有什么变化。',
        ],
        successCriteria: '你不是直接带着旧状态上场，而是先做了一次进入状态。',
        fallbackAction: '把可视化缩到 1 分钟。',
        recordFocus: '记录哪一个状态动作最有用。',
      );
    case 'L15-19::stretch':
      return HappinessActionPlanSpec(
        intro: '连续几次在高压前做状态进入，建立自己的上场前仪式。',
        steps: <String>[
          '选一个你未来一周会重复遇到的紧张场景。',
          '为它设计固定上场前仪式：一句提醒 + 一段可视化 + 三次呼吸。',
          '每次都照此执行。',
          '每次做完后记录有效度。',
          '一周后保留最有效的那一版仪式。',
        ],
        successCriteria: '你开始拥有一个稳定的状态进入模板。',
        fallbackAction: '先连续两次。',
        recordFocus: '记录哪个环节最能让你从慌乱切回行动状态。',
      );
    case 'L15-21::standard':
      return HappinessActionPlanSpec(
        intro: '练一次“支持而不控制”，让帮助更像陪伴而不是接管。',
        steps: <String>[
          '选一个你想帮助的重要的人。',
          '先写下你本来想直接纠正他的地方。',
          '改成一个支持式动作，例如分享自己的经验、肯定他的尝试、提出一个开放问题。',
          '今天用出这个支持式动作。',
          '复盘：这次更像在支持，还是更像在控制。',
        ],
        successCriteria: '你把帮助从控制改成了一次支持。',
        fallbackAction: '先把想说教的话写下来，不直接说出口。',
        recordFocus: '记录你最难放下的控制冲动是什么。',
      );
    case 'L15-21::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个反复出现的关系主题上，持续练“示范 + 分享 + 过程奖励”。',
        steps: <String>[
          '选一个你总想替对方着急的关系主题。',
          '接下来三次互动都避免直接说教。',
          '每次只做三选一：示范、分享自己的故事、奖励对方一次尝试。',
          '记录对方反应与自己的控制冲动。',
          '回看：哪一种更能让关系保持张力又不压迫。',
        ],
        successCriteria: '你把支持方式从一次练习推进成了一个小周期实验。',
        fallbackAction: '先连续两次互动。',
        recordFocus: '记录“支持而不控制”最难的是哪一刻。',
      );
    case 'L15-23::standard':
      return HappinessActionPlanSpec(
        intro: '在一次现实混乱中，完整练一轮微复原而不是过度补偿。',
        steps: <String>[
          '当今天现实被打断时，先停 30 秒。',
          '写一句当前现实负荷是什么。',
          '再写一句我下一件最小现实任务是什么。',
          '只做这一件最小任务，不试图立刻救回全部。',
          '复盘：我有先恢复，还是直接冲进控制。',
        ],
        successCriteria: '你在混乱里完成了一次恢复后再推进。',
        fallbackAction: '最小任务再缩小，只做 2 分钟。',
        recordFocus: '记录混乱后的第一动作是恢复还是补偿。',
      );
    case 'L15-23::stretch':
      return HappinessActionPlanSpec(
        intro: '把微复原带进一个高负荷现实时刻，练“先收束，再重排”。',
        steps: <String>[
          '选一个你预计会很乱的现实时段。',
          '提前写好你的微复原模板：停一下 / 承认负荷 / 选下一件最小任务。',
          '混乱一来，照模板走。',
          '之后再重排接下来的顺序。',
          '记录：模板有没有减少“全乱了”的失控感。',
        ],
        successCriteria: '你在更高负荷的现实里也完成了一次先恢复再推进。',
        fallbackAction: '先在低负荷混乱场景练。',
        recordFocus: '记录哪个复原环节最帮你稳住。',
      );
    case 'L15-20::easy':
      return HappinessActionPlanSpec(
        intro: '先修正一句最伤人的内在说法，让自己有力气继续下一步。',
        steps: <String>[
          '写出今天最苛刻的一句自我责骂。',
          '想象一个你关心的人犯了同样的错，你会怎么回应。',
          '把原句改成一句真实但不羞辱自己的话。',
          '读一遍新句子，然后去做一个 5 分钟的小动作。',
        ],
        successCriteria: '你不只是安慰自己，而是带着新语气继续做了一步。',
        fallbackAction: '如果改写太难，就先删掉最伤人的那几个词。',
        recordFocus: '记录原句和改写后的句子，以及它是否影响了下一步意愿。',
      );
    case 'L15-20::standard':
      return HappinessActionPlanSpec(
        intro: '在一次真实失误后，完整做一轮“识别双重标准—改写语气—继续行动”。',
        steps: <String>[
          '选一个最近让你很想骂自己的失误。',
          '写下你对自己说的话，再写如果是朋友你会怎么说。',
          '把朋友版改成适合对自己说的版本。',
          '带着这句新话，立刻补一个现实动作，例如补救一句、重发一次、继续 10 分钟。',
          '最后记录：更善意的语气有没有帮助我从羞耻回到行动。',
        ],
        successCriteria: '你完成了一轮从责骂到行动恢复的转换。',
        fallbackAction: '先只做“识别双重标准 + 改写一句话”，动作部分缩小到 5 分钟。',
        recordFocus: '记录哪种语气更有助于恢复，而不是只让自己更难受。',
      );
    case 'L15-20::stretch':
      return HappinessActionPlanSpec(
        intro: '把白金法则直接用在一个你最容易启动羞耻和自责的现实主题上。',
        steps: <String>[
          '选一个高频让你苛责自己的主题，例如工作失误、关系表达、外表或效率。',
          '写三句你平时会怎么骂自己。',
          '逐句改写成你会对朋友说的版本。',
          '选其中一句，在今天再次被触发时强制替换使用。',
          '随后继续推进一个现实动作，不让自责把今天整段吞掉。',
        ],
        successCriteria: '你在真正被触发的时刻，使用了更善意但不放纵的新语气。',
        fallbackAction: '如果现场替换太难，就先在事后补写改写版并练下次使用。',
        recordFocus: '记录最难替换的是哪一句，以及替换后有没有帮助你继续出现。',
      );
    case 'L16-8::easy':
      return HappinessActionPlanSpec(
        intro: '让一个优势先通过一个很小的动作进入今天的任务，而不是继续只靠硬撑。',
        steps: <String>[
          '选今天必须做的一件小任务。',
          '从你熟悉的优势里挑一个最顺手的，例如爱学习、真诚、组织力。',
          '写一句“我准备让这个优势通过什么具体动作进场”。',
          '立刻做出这个动作。',
          '记录：过程有没有比原来更像我自己。',
        ],
        successCriteria: '你让一个优势通过动作而不是标签进入了现实任务。',
        fallbackAction: '如果挑优势太难，就先选你最自然的一项，再做最小动作。',
        recordFocus: '记录优势具体做了什么，而不是只写“我用了某个优势”。',
      );
    case 'L16-8::standard':
      return HappinessActionPlanSpec(
        intro: '把一个优势完整地绑定到今天的一件现实任务里，看看过程体验会不会改变。',
        steps: <String>[
          '选一个今天中等重要的任务。',
          '先写任务本来会怎样被你硬撑完成。',
          '再写如果调用某个优势，这个任务会多出哪个具体动作。',
          '按这个新动作完成任务。',
          '结束后记录：过程里的活力感、投入感、真实性有没有变化。',
        ],
        successCriteria: '你完成了一次“同一任务，不同过程”的对照实验。',
        fallbackAction: '先只在任务的一个小环节调动优势，不要求全程切换。',
        recordFocus: '记录调用优势前后，过程体验最明显的变化。',
      );
    case 'L16-8::stretch':
      return HappinessActionPlanSpec(
        intro: '把优势直接带进一个你原本只会靠控制、拖延或硬撑处理的难题里。',
        steps: <String>[
          '选一个你最近反复觉得“好累但还得做”的问题。',
          '判断哪个优势最可能改变这件事的做法，而不仅是改变感受。',
          '把优势翻译成一个会被现实看见的动作，例如发起一次真实沟通、查清一个关键问题、重构任务结构。',
          '在今天就做出这个动作。',
          '最后记录：这个优势有没有让你更接近“真实的我”，而不是更远。',
        ],
        successCriteria: '你把优势真正当成了解题工具，而不再只是自我标签。',
        fallbackAction: '先在问题里切出一个小片段，只对这一段使用优势。',
        recordFocus: '记录优势介入后，问题和你自己的关系有什么变化。',
      );

    case 'L15-6::easy':
      return HappinessActionPlanSpec(
        intro: '先把“把一次失败改写成螺旋节点”压缩成今天就能完成的最小练习，不求漂亮，只求真实出现。',
        steps: <String>[
          '写下最近一次不顺，限定在一件具体小事，例如“今天汇报被追问”“这周计划断掉了”。',
          '写出你脑中最自动的一句旧解释，例如“这条路不对了”“是不是我不行”。',
          '把它改写成一句新解释：“这不是直线偏离，而是我成长螺旋上的一个节点。”',
          '再补一行：这次更像绕路、停顿、回撤还是重练。',
          '把纸面内容拍照或保存下来，作为今天的事实记录。',
        ],
        successCriteria: '你完成了一次具体改写，而不是继续在脑内笼统否定自己。',
        fallbackAction: '如果连完整改写都太大，就只写下“旧解释一句 + 新解释一句”。',
        recordFocus: '重点记录旧解释是什么，新解释是什么，写完后身体和情绪有没有一点松动。',
      );
    case 'L15-6::standard':
      return HappinessActionPlanSpec(
        intro: '把最近一次不顺从“直线失败”翻译成“螺旋练习节点”，再补一个现实恢复动作。',
        steps: <String>[
          '选一个最近 72 小时内的真实事件，最好是你还在反复想的。',
          '写三行：发生了什么；我原来怎么解释；如果按螺旋成长理解，我现在怎么解释。',
          '从事件里选一个最小恢复动作，例如重开 10 分钟、补发一条说明、约一个继续推进的时间。',
          '在今天就把这个恢复动作做掉，不拖到“完全想通”。',
          '做完记录：这次我更像继续上场，还是仍在试图把曲线掰回直线。',
        ],
        successCriteria: '你不仅改写了解释，还做了一个现实恢复动作。',
        fallbackAction: '如果现实恢复动作太大，就缩回到只做 5 分钟版本，但不要整条放弃。',
        recordFocus: '记录恢复动作是否真的发生，以及它有没有让你重新回到训练轨道。',
      );
    case 'L15-6::stretch':
      return HappinessActionPlanSpec(
        intro: '把“允许曲线”直接放进一个你本来会过度控制或拖延的重要现实任务。',
        steps: <String>[
          '选一个你现在正因为怕不完美而拖着的重要任务，例如一版稿子、一次表达、一个决定。',
          '先写“卓越版标准”：认真推进关键部分，但允许出现一处不完美。',
          '给自己一个明确时段，例如 25 分钟，在这段时间里只做关键推进，不反复检查。',
          '到点后必须输出一个现实版本，例如发出一版、开口表达一次、做出一个决定。',
          '之后记录：我在哪里允许了曲线存在，我又在哪里还在强迫自己回到直线。',
        ],
        successCriteria: '你在更真实的不确定里，仍然维持了和本段概念一致的行动。',
        fallbackAction: '把暴露度降一档，先输出给安全对象或先做一个半公开版本。',
        recordFocus: '记录你输出了什么、哪里卡住了、允许一处不完美后真实发生了什么。',
      );
    case 'L14-3::easy':
      return HappinessActionPlanSpec(
        intro: '先把脑中的“完了”写清楚，不急着证明自己没事。目标是把灾难化拆成可分析的条目。',
        steps: <String>[
          '选一件你正在回避的小风险事件，例如发消息、开口提需求、发出一个版本。',
          '写下脑中最吓人的一句原话，例如“如果被拒绝我就很丢脸”。',
          '把“最坏结果”拆成 1 到 3 个具体事件，不要写模糊的“全完了”。',
          '给每个最坏结果各写一个应对动作，例如解释一句、重发一次、换一个对象、改天再试。',
          '最后判断：这件事是高风险，还是高不适但可承受。',
        ],
        successCriteria: '你把灾难化从模糊恐惧拆成了具体后果和应对。',
        fallbackAction: '如果写完整表太难，就先只写“最坏一句话 + 一个应对动作”。',
        recordFocus: '记录真正吓到你的到底是哪一个具体后果，而不是笼统写“我很怕”。',
      );
    case 'L14-3::standard':
      return HappinessActionPlanSpec(
        intro: '做一张“最坏情况—可承受性—下一步”的三列表，然后立刻把它带回现实中的一个小动作。',
        steps: <String>[
          '针对一件你正在拖开的事，分别写：最坏会发生什么、我如何应对、即便发生我能学到什么。',
          '在每一列里都只写具体句子，不写“很糟”“完蛋了”这种总括性词。',
          '从表里选一个最可承受的小动作，例如发出一条消息、确认一个时间、先做半公开版本。',
          '在今天就把这一步做掉，不再无限停留在评估里。',
          '做完后补一句：真实发生的结果和我原来脑补的最坏差了多少。',
        ],
        successCriteria: '你完成了风险重估，并把它转成了一个现实中的前进行动。',
        fallbackAction: '如果行动还太大，就先只完成三列表，并把动作缩成发给安全对象的版本。',
        recordFocus: '记录脑补最坏结果和真实结果之间的差异。',
      );
    case 'L14-3::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你通常会因为灾难化而退开的场景里，做一次“评估后仍然迈步”的训练。',
        steps: <String>[
          '挑一个你已经拖了一阵的高不适情境，例如主动争取、表达需求、给出真实反馈。',
          '先快速写三列：最坏结果、应对动作、我仍然能承受的理由。',
          '选定一个清晰动作并设置开始时间，不允许再临场加更多准备条件。',
          '按计划执行，过程中只允许看一次你刚写的三列表，而不是重新脑补。',
          '结束后记录：真正难的是结果，还是迈出那一步前的想象。',
        ],
        successCriteria: '你没有等恐惧完全消失，而是在完成风险重估后仍然行动了。',
        fallbackAction: '把公开动作降级成半公开或私下版本，但保持今天内完成。',
        recordFocus: '记录真正的痛点到底在预期、执行还是结果阶段。',
      );
    case 'L15-18::easy':
      return HappinessActionPlanSpec(
        intro: '先做一次很小的“行为先行”练习，用一个现实动作打破“等想通了再做”。',
        steps: <String>[
          '选一个你已经想了很久但一直没做的小动作，例如问一个问题、发出一版、补一句表达。',
          '把动作压缩到 5 分钟内能完成的版本。',
          '在开始前只写一句你最担心的旧想法，不继续分析。',
          '立刻完成这个动作。',
          '做完后只记录两件事：我真的做了什么；现实有没有像我脑补的一样糟。',
        ],
        successCriteria: '你用行动而不是继续思考，推动了一次真实接触。',
        fallbackAction: '如果还是太难，就把动作再减半，只完成“出现一次”的版本。',
        recordFocus: '记录从“想做”到“真的做”之间，最卡的那一秒发生了什么。',
      );
    case 'L15-18::standard':
      return HappinessActionPlanSpec(
        intro: '针对一个你经常靠回避维持体面的情境，设计并完成一次行为先行训练。',
        steps: <String>[
          '写下一个你常回避的真实情境，例如索取反馈、表达不同意见、发出完成版。',
          '明确一个可观察动作，例如“发出邮件”“约到 10 分钟反馈”“把问题问出口”。',
          '写出旧剧本：“等更稳一点再说/再改一次再交/别给自己找丢脸机会”。',
          '在预定时间按动作执行，不允许中途改成纯准备活动。',
          '执行后记录事实，并补一句：这次我用行为改了什么态度。',
        ],
        successCriteria: '你完成了一次对旧剧本有明确挑战的行为训练。',
        fallbackAction: '把对象换成更安全的人，或把动作缩成先发半成品。',
        recordFocus: '记录旧剧本最想拉你回去的那个瞬间。',
      );
    case 'L15-18::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更接近你核心回避主题的情境里，做一次带反馈的不舒服训练。',
        steps: <String>[
          '挑一个你通常最想躲的现实动作，例如请求真实反馈、接受被拒绝、发出重要表达。',
          '提前写一句稳住自己的提醒：“我现在练的不是完美，而是承受并继续行动。”',
          '完成动作后，不立刻解释、撤回或过度补偿。',
          '把收到的反馈或结果原样记录下来。',
          '最后决定下一次是保持同难度，还是缩小一点继续练。',
        ],
        successCriteria: '你在更高不适里，仍然没有退回旧剧本。',
        fallbackAction: '先把反馈对象换成信任的人，但保持“今天发出去”。',
        recordFocus: '记录你在听到反馈或面对拒绝后，最想立刻做的防御动作是什么。',
      );
    case 'L15-22::easy':
      return HappinessActionPlanSpec(
        intro: '用一张最小版 Three Ps 卡，把自己从自动失控里先拉回一点点。',
        steps: <String>[
          '写下此刻最难受的一件事，只写一件。',
          '在下面写第一行：Permission —— 这很难，我现在这样反应很正常。',
          '第二行：Positive —— 这件事里我至少能学到什么或看见什么。',
          '第三行：Perspective —— 一周后/一年后，它还会同样大吗。',
          '写完后只做一个最小恢复动作，例如喝水、走动 3 分钟、回到手边最小任务。',
        ],
        successCriteria: '你没有继续跟着情绪滚，而是把自己拉回了可行动状态。',
        fallbackAction: '如果写三行都太难，就只先写 Permission 那一句。',
        recordFocus: '记录写完三行后，身体和脑中的紧绷有没有下降一点。',
      );
    case 'L15-22::standard':
      return HappinessActionPlanSpec(
        intro: '在一次现实混乱中完整用一次 Three Ps，而不是事后才想起来。',
        steps: <String>[
          '当你开始急、乱、烦时，先停 30 秒，不直接往下冲。',
          '口头或纸面完成 Three Ps：允许自己是人；找一点可学习处；拉远时间尺度。',
          '然后把当前任务拆成“现在最先处理的一件事”和“之后再处理的事”。',
          '先完成最先处理的那一步，不要求一口气收拾全部混乱。',
          '结束后记录：哪个 P 对你最有帮助，哪个最难做到。',
        ],
        successCriteria: '你在混乱中完成了一次完整恢复流程，而不是只停在情绪里。',
        fallbackAction: '如果三步来不及，就先做 Permission + 下一件最小任务。',
        recordFocus: '记录你是在哪个环节重新恢复了行动能力。',
      );
    case 'L15-22::stretch':
      return HappinessActionPlanSpec(
        intro: '把 Three Ps 用在一个更会触发你旧剧本的现实场景里，例如失误、迟到、被追问或计划崩掉。',
        steps: <String>[
          '提前准备一张 Three Ps 小卡或手机备忘。',
          '当高压场景真的发生时，不去追求立刻完美修复，而是先照卡片完成三步。',
          '做完三步后，立刻选一个对现实最有帮助的动作，例如说明情况、重排优先级、先完成一小块。',
          '允许自己在不完美状态下继续往前，而不是先解决“我怎么会这样”。',
          '事后记录：哪一步最拯救你，哪一步下次要练得更熟。',
        ],
        successCriteria: '你把 Three Ps 用在了真正触发旧模式的现场，而不是只在平静时理解它。',
        fallbackAction: '如果现场做不全，就先只完成 Permission 和一个现实动作。',
        recordFocus: '记录你从混乱回到行动，靠的究竟是哪一步。',
      );
    case 'L16-10::easy':
      return HappinessActionPlanSpec(
        intro: '先用一个你最自然的优势，去解决一个很小但真实的问题。',
        steps: <String>[
          '先写一个今天真的在卡你的小问题。',
          '再写一个你比较像“真正的我”的优势，例如学习、真诚、组织、幽默、坚持。',
          '问自己：如果只用这个优势帮今天的我一点点，我会做什么。',
          '把答案压缩成一个 10 分钟动作并执行。',
          '记录：我用了哪个优势，它具体怎么帮助了我。',
        ],
        successCriteria: '你不是泛泛知道自己的优势，而是真把它拿去解决了一个问题。',
        fallbackAction: '如果想不出优势，先从“我做这件事时什么时候最像自己”开始写一句。',
        recordFocus: '记录优势不是标签，而是在现实里变成了什么动作。',
      );
    case 'L16-10::standard':
      return HappinessActionPlanSpec(
        intro: '选一个最近反复出现的问题，让你的优势真正参与进来，而不是继续硬扛。',
        steps: <String>[
          '定义一个具体问题，例如“我总回避反馈”“我和伴侣一冲突就关掉自己”。',
          '选一个最 relevant 的优势，例如学习、真实性、领导力、审慎、感恩。',
          '写出“如果让这个优势来处理这个问题，它会怎么做”的三步版本。',
          '今天执行第一步，不要求一次解决问题，只要求优势真正上场。',
          '记录：比起原来的旧方式，这次多了什么不同。',
        ],
        successCriteria: '你让优势从自我认识变成了现实中的问题解决工具。',
        fallbackAction: '如果问题太大，就只挑其中一个具体场景做优势介入。',
        recordFocus: '记录优势介入后，你的感受、行为或结果发生了什么小变化。',
      );
    case 'L16-10::stretch':
      return HappinessActionPlanSpec(
        intro: '把一个核心优势用到你最容易掉回旧剧本的领域里，做一次更真实的迁移。',
        steps: <String>[
          '选一个你反复觉得“我就是改不了”的老问题。',
          '明确一个你最有活力感的优势，并写一句为什么它和这个问题相关。',
          '用这个优势设计一个现实动作，例如用真实性开一场真对话、用学习系统梳理恐惧、用领导力主动组织推进。',
          '在本周内完成这个动作，并保留事实记录。',
          '复盘：优势真的有没有改变你处理问题的方式，还是你又回到了旧剧本。',
        ],
        successCriteria: '你完成了一次“优势迁移”，而不是只把优势停在测试结果里。',
        fallbackAction: '把动作缩小成一次准备型介入，但仍然要求本周完成。',
        recordFocus: '记录“当我像真正的我那样行动时，问题有没有松动一点”。',
      );

    case 'L15-7::easy':
      return HappinessActionPlanSpec(
        intro: '先把“半杯空 / 防御性”压成一个很小的反馈训练，不求当场表现完美。',
        steps: <String>[
          '找一个今天已经收到或即将收到的小反馈。',
          '先不解释，先写两条已经成立或已经做到的部分。',
          '再写一条真实问题，不多写。',
          '只针对这一个问题决定一个 5 分钟改动动作。',
          '做完后记录：我更像在学习，还是更像在防御。',
        ],
        successCriteria: '你没有只盯缺口，而是把反馈转成了一个小改动。',
        fallbackAction: '如果现实反馈太难，就先拿自己最近的一次自我不满做这个练习。',
        recordFocus: '记录我最想解释的那一刻，以及我有没有先看到已经成立的部分。',
      );
    case 'L15-7::standard':
      return HappinessActionPlanSpec(
        intro: '做一次完整的“先看见防御，再把反馈转成学习”的训练。',
        steps: <String>[
          '选一个真实反馈场景，例如工作、关系或自我审视。',
          '先写：我最想立刻辩解或攻击回去的点是什么。',
          '再写两列：已经成立的部分 / 这次真正要改的一点。',
          '今天只做一个具体修正，不同时修很多点。',
          '最后记录：如果我不再只看半杯空，我会怎么继续。',
        ],
        successCriteria: '你完成了一轮从防御到学习的切换。',
        fallbackAction: '如果真实反馈太刺激，就先对一个较小的反馈做同样流程。',
        recordFocus: '记录我先看见的是问题，还是先看见了完整现实。',
      );
    case 'L15-7::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更容易触发防御的场景里，练习不急着自我保护，而是先学习。',
        steps: <String>[
          '选一个你最容易被点燃防御的反馈场景。',
          '提前写一句稳住自己的提醒：“先学，再决定要不要解释。”',
          '进入场景后先听完，不打断。',
          '事后只选一个具体点做修改，不全面反扑。',
          '记录：不防御的成本是什么，不防御的收获又是什么。',
        ],
        successCriteria: '你在更高刺激的反馈里，仍然保住了学习姿态。',
        fallbackAction: '把反馈对象换成更安全的人，但保留“先学后答”这一核心。',
        recordFocus: '记录我最想立刻解释的瞬间，以及我是怎么没被它拉走的。',
      );
    case 'L15-10::easy':
      return HappinessActionPlanSpec(
        intro: '先把“关系里有问题”从“关系错了”里分出来。',
        steps: <String>[
          '选最近一次关系里的小失望，不选太大事件。',
          '写一句旧解释，例如“如果关系对，就不该这样”。',
          '改写成一句新解释：“关系里出现落差，不等于关系作废。”',
          '再写一个最小修复动作，例如补一句澄清、约一次沟通、表达一个真实感受。',
          '记录：我是在维护完美想象，还是在练关系修复。',
        ],
        successCriteria: '你把一个关系落差转成了一个修复动作。',
        fallbackAction: '如果修复动作太大，就先只做改写和准备一句真实表达。',
        recordFocus: '记录这次我最怕的是关系结束，还是怕面对失望本身。',
      );
    case 'L15-10::standard':
      return HappinessActionPlanSpec(
        intro: '对一个真实的关系落差，完成一次“承认—表达—修复”的标准训练。',
        steps: <String>[
          '定义一次最近的落差：发生了什么，不做夸张解释。',
          '写旧剧本：“好关系不该有这种事。”',
          '写新剧本：“关键不是有没有负面，而是我怎么回应负面。”',
          '按这个新剧本，发起一个真实但可承受的修复动作。',
          '结束后记录：动作有没有让我更靠近真实关系，而不是理想模板。',
        ],
        successCriteria: '你没有把问题直接判成关系错误，而是完成了一个修复动作。',
        fallbackAction: '把沟通改成文字版，或先缩成一小句真实表达。',
        recordFocus: '记录我有没有把“关系里有问题”直接解释成“关系本身错了”。',
      );
    case 'L15-10::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个更真实的关系冲突或失望场景里，练习不理想化、不判死刑，而是继续修复。',
        steps: <String>[
          '选一个你最容易启动完美关系想象的主题。',
          '提前写下：今天我要练的是“可修复”，不是“绝对无负面”。',
          '进入沟通后先说事实和感受，不先说结论。',
          '提出一个具体修复请求，而不是要求对方整体变完美。',
          '复盘：我更接近真实关系了，还是更接近理想模板了。',
        ],
        successCriteria: '你在更难的关系情境里，仍然把重点放在修复而不是判决。',
        fallbackAction: '把冲突主题降级一点，但保留“事实+感受+请求”的结构。',
        recordFocus: '记录我是在追求“没有问题”，还是在练“出现问题后的回应”。',
      );
    case 'L16-3::easy':
      return HappinessActionPlanSpec(
        intro: '先识别我当前这件事更像差事、事业还是召唤，不急着做大决定。',
        steps: <String>[
          '选今天必须做的一件任务。',
          '分别用三句话写：如果把它当差事/事业/召唤，我会怎么理解它。',
          '圈出现在最像你实际状态的一种。',
          '再写一句：怎样让它比现在多一点意义或自主感。',
          '今天就把这句话变成一个小动作。',
        ],
        successCriteria: '你完成了一次工作叙事识别，并做了一个微调动作。',
        fallbackAction: '如果三种都分不清，就先只写“我现在最像是在赶什么”。',
        recordFocus: '记录这件事现在更像 job、career 还是 calling。',
      );
    case 'L16-3::standard':
      return HappinessActionPlanSpec(
        intro: '选一件当前任务，做一次“从赶下一站改成补一层意义”的训练。',
        steps: <String>[
          '定义一个你最近只想赶快做完的任务。',
          '写出你现在的驱动：为了交差、为了下一站，还是因为它本身重要。',
          '补一句真实意义：它服务了谁、成全了什么、锻炼了什么。',
          '按这个意义版本完成一个具体动作。',
          '记录：这样做时，过程有没有比原来更能投入一点。',
        ],
        successCriteria: '你让任务多了一层真实意义，而不是只剩推进。',
        fallbackAction: '如果整件任务太重，就只挑其中一个小环节做这个练习。',
        recordFocus: '记录“赶下一站”和“看见这一步意义”时，身体和投入感的差别。',
      );
    case 'L16-3::stretch':
      return HappinessActionPlanSpec(
        intro: '把一个你长期只当作差事/赛跑的领域，重新接回一点 calling 感。',
        steps: <String>[
          '选一个你最近最容易发空的工作或学习领域。',
          '写明：我现在主要被什么驱动。',
          '再写：如果把它多看作一点使命或价值，这会怎样改变我今天的一步。',
          '今天就执行这一步，哪怕很小。',
          '复盘：我不是忽然热爱一切，而是有没有多一点真实投入。',
        ],
        successCriteria: '你把 calling 从概念，拉回到今天的一步现实动作。',
        fallbackAction: '如果 calling 太大，就先只补“这一步对谁有价值”。',
        recordFocus: '记录我今天更像在赶路，还是在活。',
      );
    case 'L16-5::easy':
      return HappinessActionPlanSpec(
        intro: '先练习区分“这部分很无聊”和“整条路没意义”不是一回事。',
        steps: <String>[
          '选今天一个你很烦但又必要的小环节。',
          '写一句旧想法：“如果这条路真适合我，就不该这么烦。”',
          '改写成一句新想法：“局部无聊，不等于整体错误。”',
          '带着这句新想法完成 5 到 10 分钟这个环节。',
          '记录：我今天为什么仍愿意做它。',
        ],
        successCriteria: '你在无聊里没有直接否定整条路。',
        fallbackAction: '把时间压缩到 3 分钟，但仍保留“带着意义做一下”。',
        recordFocus: '记录我是在反感这个环节，还是在否定整个方向。',
      );
    case 'L16-5::standard':
      return HappinessActionPlanSpec(
        intro: '在一个重复或枯燥环节里，练习“整体意义托住局部无聊”。',
        steps: <String>[
          '选一个你反复想拖的准备性、重复性任务。',
          '写这个环节服务于哪一个更大的在乎。',
          '设 15 分钟，只专心做这一段，不一边抱怨一边到处切换。',
          '到点后停下来，记录：我有没有更清楚这段为什么值得。',
          '补一个下一次继续的最小时间点。',
        ],
        successCriteria: '你完成了一个“带着整体意义做局部无聊”的训练。',
        fallbackAction: '把枯燥环节再切小一半，但仍保留它服务于什么。',
        recordFocus: '记录整体意义有没有真的减少我对局部无聊的敌意。',
      );
    case 'L16-5::stretch':
      return HappinessActionPlanSpec(
        intro: '把一个你最想逃的枯燥环节，当作“承载 calling 的能力训练”来做。',
        steps: <String>[
          '选一个你通常会因为太烦而中断的必要环节。',
          '写一句：如果我真重视这条路，我愿意如何对待这个环节。',
          '在一个较长时段里做完关键部分，不靠情绪驱动。',
          '过程中每次想逃时，只提醒自己回到“整体在乎”。',
          '结束后记录：我有没有更能承载 calling 里并不光鲜的部分。',
        ],
        successCriteria: '你完成了一次“带着整体意义承载局部无聊”的高阶训练。',
        fallbackAction: '把时段缩短，但保留“想逃时回到整体在乎”的动作。',
        recordFocus: '记录我是不是把 calling 误解成了“每一分钟都必须喜欢”。',
      );
    case 'L16-6::easy':
      return HappinessActionPlanSpec(
        intro: '先给当前角色重写一个更有价值感的版本，再做一个小动作验证它。',
        steps: <String>[
          '选今天一件你觉得只是机械完成的任务。',
          '写旧版本：这只是我必须做完的差事。',
          '写新版本：这件事其实服务了谁、保护了谁、支持了什么。',
          '按新版本做一个小动作。',
          '记录：这样做时，我有没有更像一个在参与，而不只是应付。',
        ],
        successCriteria: '你完成了一次从差事叙事到价值叙事的切换。',
        fallbackAction: '如果价值感很薄，就先写“这至少减轻了谁的麻烦”。',
        recordFocus: '记录“只是在干活”和“我其实在服务一个链条”之间的差别。',
      );
    case 'L16-6::standard':
      return HappinessActionPlanSpec(
        intro: '把当前工作/学习的一小段，从“差事”重写成“有价值的角色动作”。',
        steps: <String>[
          '定义一个你最近最容易机械应付的角色任务。',
          '写这项任务在更大系统里的作用，不用夸大，只写真实。',
          '再写：如果我按这个价值版本做，今天的一步会怎么不同。',
          '执行这一步。',
          '复盘：价值叙事有没有改变我的投入方式。',
        ],
        successCriteria: '你让新的角色理解真实影响了一个现实动作。',
        fallbackAction: '只挑任务里的一个小片段做价值重写，不求全任务改变。',
        recordFocus: '记录我是因为看见价值而行动，还是只是换了一句好听解释。',
      );
    case 'L16-6::stretch':
      return HappinessActionPlanSpec(
        intro: '在一个你长期觉得“这只是差事”的领域里，练习把价值理解真正带进行为。',
        steps: <String>[
          '选一个你最常机械推进的领域。',
          '写出你旧的工作叙事。',
          '重写一个更真实、更大的价值版本。',
          '设计并完成一个会被现实看见的动作，证明这个新叙事不是空话。',
          '最后记录：我今天更像在交差，还是更像在承担一个角色。',
        ],
        successCriteria: '你把新的意义理解落成了一个现实可见动作。',
        fallbackAction: '先对这个领域里的一个小任务试做新叙事动作。',
        recordFocus: '记录新的角色理解有没有真的影响我的行为，而不只是让我短暂感觉好一点。',
      );
    case 'L15-11::easy':
      return HappinessActionPlanSpec(
        intro: '先把“高压推进”改成一次更可持续的推进，不追求今天直接翻盘。',
        steps: <String>[
          '选今天最想靠狠劲硬推的一件事。',
          '写下旧剧本：我准备怎么逼自己。',
          '把它改成一个 10 到 15 分钟的可持续版本，只做关键部分。',
          '做完后停下，不用额外补偿式加码。',
          '记录：节奏慢一点后，我是否反而更能继续。',
        ],
        successCriteria: '你保住了一次可持续推进，而不是又靠爆冲。',
        fallbackAction: '把时间再减半，只做最关键的一步。',
        recordFocus: '记录我今天放下了哪一种“必须更狠”的冲动。',
      );
    case 'L15-12::easy':
      return HappinessActionPlanSpec(
        intro: '先抓住一个正在影响你的完美模板，并把它拆成现实可辨认的东西。',
        steps: <String>[
          '写下今天最让你开始自我否定的一个外部模板。',
          '写出这个模板暗中要求你“必须怎样”。',
          '再写一句更真实的人类版本标准。',
          '按这个新标准做一个小动作。',
          '记录：模板的力道有没有被你拆弱一点。',
        ],
        successCriteria: '你没有直接照单全收，而是对模板做了第一次拆解。',
        fallbackAction: '先只写模板和它要求你的那句话。',
        recordFocus: '记录我最容易被哪种外部完美模板牵走。',
      );
    case 'L15-14::easy':
      return HappinessActionPlanSpec(
        intro: '练一次“先抓关键，不全做完美”。',
        steps: <String>[
          '列出今天要做的所有部分。',
          '圈出真正影响结果的 1 到 2 项。',
          '把其他部分统一降到“够好完成”。',
          '先完成关键部分。',
          '记录：哪一部分其实最值钱。',
        ],
        successCriteria: '你把精力放回了关键推进，而不是平均耗散。',
        fallbackAction: '如果还是难以取舍，就先只选最重要的一项。',
        recordFocus: '记录我今天放下了哪些“其实没那么关键”的完美要求。',
      );
    case 'L15-17::easy':
      return HappinessActionPlanSpec(
        intro: '先练习一句主动接纳，再带着它继续一个小动作。',
        steps: <String>[
          '写下这个老问题又来的时刻。',
          '补一句：“我知道你还会来，但我今天仍然会往前一点。”',
          '选一个 5 分钟小动作去做。',
          '做完后记录：问题还在时，我依然完成了什么。',
        ],
        successCriteria: '你没有等彻底没有问题才开始行动。',
        fallbackAction: '如果现实动作太难，就先只写接纳句并做准备动作。',
        recordFocus: '记录今天我有没有带着问题继续行动。',
      );
    case 'L15-19::easy':
      return HappinessActionPlanSpec(
        intro: '用一次最短可视化，帮自己更稳地进入一个真实场景。',
        steps: <String>[
          '选一个今天会让你紧张的场景。',
          '闭眼 1 分钟，想象自己更稳地出现。',
          '再做 3 次慢呼吸。',
          '立刻进入场景，做一个最小现实动作。',
          '记录：可视化有没有帮你少一点僵。',
        ],
        successCriteria: '你把可视化接到了现实动作，而不是只停在想象里。',
        fallbackAction: '把可视化缩成一句提示语和一次深呼吸。',
        recordFocus: '记录状态切换前后身体最明显的变化。',
      );
    case 'L15-21::easy':
      return HappinessActionPlanSpec(
        intro: '练一次“少说教，多分享”的支持动作。',
        steps: <String>[
          '想一个你最近很想纠正的人。',
          '把你想说教的内容先写下来，但先不发。',
          '改写成一个自己的小故事或小经验。',
          '只发分享版本，不发教训版本。',
          '记录：这样做后，对方和我自己的状态有什么不同。',
        ],
        successCriteria: '你完成了一次支持而非控制的表达。',
        fallbackAction: '先只把说教版和分享版都写出来，不一定今天发。',
        recordFocus: '记录我是在支持别人，还是在急着让别人按我的节奏变好。',
      );
    case 'L15-23::easy':
      return HappinessActionPlanSpec(
        intro: '练一次混乱中的微复原，不让自己一乱就全盘失控。',
        steps: <String>[
          '抓今天一个节奏被打乱的小瞬间。',
          '先承认“现在就是有点乱”。',
          '只列出下一件最关键的事。',
          '先做那一件，不去同时救全部。',
          '记录：这样做后，我有没有更快恢复。',
        ],
        successCriteria: '你没有把混乱升级成全面崩盘，而是完成了一次收束。',
        fallbackAction: '如果还是太乱，就先只写下一件事，不要求立刻做完。',
        recordFocus: '记录我是在混乱里先恢复，还是先补偿式硬冲。',
      );
    case 'L16-1::easy':
      return HappinessActionPlanSpec(
        intro: '先把一点点注意力从结果拉回过程。',
        steps: <String>[
          '选今天正在推进的一件事。',
          '写下你最在意的终点。',
          '再写一句：如果只看今天这一步，我想怎样走。',
          '按这句过程提醒做 10 分钟。',
          '记录：过程里有没有多一点在场感。',
        ],
        successCriteria: '你把幸福从未来终点拉回了一点到今天过程。',
        fallbackAction: '如果 10 分钟太多，就先做 3 分钟过程观察。',
        recordFocus: '记录我什么时候又把注意力全扔给终点了。',
      );
    case 'L16-9::easy':
      return HappinessActionPlanSpec(
        intro: '先抓一个真实的活力时刻，不追求今天就找到完整答案。',
        steps: <String>[
          '今天留意一个你明显更有活力的瞬间。',
          '立刻写下当时你在做什么。',
          '补一句：那一刻我更像自己，是因为我怎样出现。',
          '从这句里提炼一个下次可重复的小动作。',
          '记录：这是不是一个“真实自我”的线索。',
        ],
        successCriteria: '你抓住了一个“这才是我”的可观察样本。',
        fallbackAction: '如果今天没有明显时刻，就回想最近三天的一次。',
        recordFocus: '记录那个活力时刻里的动作、环境和关系线索。',
      );

    default:
      final easy = level == 'easy';
      final stretch = level == 'stretch';
      final List<String> how = unit.howSteps.take(3).toList();
      final String life = unit.lifeCases.isNotEmpty ? unit.lifeCases.first : unit.oneLiner;
      final String sample = unit.courseCases.isNotEmpty ? unit.courseCases.first : unit.summary;
      return HappinessActionPlanSpec(
        intro: easy
            ? '先把这段课压缩成一个今天就能做的最小动作，优先练“出现一次”。'
            : stretch
                ? '把本段概念放进一个更真实、更有不确定性的现实情境里练一次。'
                : '把本段概念翻译成一个标准训练动作，并在今天完成一轮。',
        steps: <String>[
          '先选一个今天真实会发生的情境：${spec.trigger}',
          '参照本段原内容和现实案例，把这个情境具体化成一句现实版本，例如：$life',
          '写下最自动的旧想法：${spec.thought}；并补一句它最像课程中的哪个原场景：$sample',
          if (how.isNotEmpty) '按本段“怎样做”先完成第一步：${how.first}',
          if (how.length > 1) '接着完成第二步：${how[1]}',
          if (how.length > 2) '如果还做得动，再补第三步：${how[2]}',
          easy
              ? '把“${unit.defaultActionTitle}”压缩成 5 到 10 分钟版本，只保留一个最小动作。'
              : stretch
                  ? '在真实情境里直接做一次“${unit.defaultActionTitle}”，并增加一点反馈、暴露或不确定性。'
                  : '按“${unit.defaultActionTitle}”做一次完整但可控的训练，不等完全准备好才开始。',
          '做完后立刻补一条事实记录：发生了什么、我做了什么、结果怎样。',
          '最后决定下一步：继续一次、缩小一次，还是换到更接近现实的版本。',
        ],
        successCriteria: easy
            ? '你真的做了一次最小动作，而不是继续停在理解和准备层。'
            : stretch
                ? '你在更真实的场景里，仍然做出了与本段概念一致的动作。'
                : '你完成了一次完整训练，并留下了事实记录。',
        fallbackAction: easy
            ? '如果还是做不到，就只做“写一句现实版本 + 写一句旧想法 + 做一个 3 分钟动作”。'
            : stretch
                ? '把不确定度降一个档位，先回到标准训练版。'
                : '把动作减半，只做关键一步，但不要整条放弃。',
        recordFocus: spec.fact,
      );
  }
}
