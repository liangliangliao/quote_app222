import 'will_models.dart';

WillDeepLessonContent getWillDeepLessonContent(WillUnitIndex unit) {
  final zone = _zone(unit.moduleCode);
  final key = '${unit.moduleCode}:${unit.id}';
  final explicit = _explicit[key];
  if (explicit != null) return explicit;
  if (unit.moduleCode == 'D') return _introCluster(unit, zone);
  if (unit.moduleCode == 'I') return _ideoMotorCluster(unit, zone);
  if (unit.moduleCode == 'A') return _deliberationCluster(unit, zone);
  if (unit.moduleCode == 'T') return _decisionCluster(unit, zone);
  if (unit.moduleCode == 'E') return _effortCluster(unit, zone);
  if (unit.moduleCode == 'P') return _pleasureCluster(unit, zone);
  if (unit.moduleCode == 'O') return _obstructedCluster(unit, zone);
  if (unit.moduleCode == 'X') return _explosiveCluster(unit, zone);
  if (unit.moduleCode == 'R') return _relationCluster(unit, zone);
  if (unit.moduleCode == 'F') return _freedomCluster(unit, zone);
  if (unit.moduleCode == 'W') return _educationCluster(unit, zone);
  return WillDeepLessonContent(
    originalKeyPoint: '这一单元的原始要点是：${unit.oneLiner}',
    coreMeaning: '它帮助你把抽象意志机制落到现实中，判断当前是冲动过快、阻滞过强、注意失守，还是需要 effort 去维持正确观念。',
    extension: '它适用于学习、工作、关系、自我管理、目标推进等需要把“知道”转成“做到”的情境。',
    realCase: '把它放回你最近最真实的一个困扰里：拖延、冲动、犹豫、回避、明知不做，都可以用这个单元来解释其中一环。',
    practiceAction: '今天用这个单元做一个 2 分钟最小动作：先识别机制，再做一次很小的现实介入。',
    ifThen: '如果这个问题再次出现，那么我先让正确观念在心里多停留 10 秒，再做一个最小动作。',
    mirrorZone: zone,
    reviewPrompt: '今天「${unit.title}」最像出现在什么情境？下次我最早能在哪个点介入？',
  );
}


WillDeepLessonContent _introCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _introOriginalPoint(unit),
    coreMeaning: _introCoreMeaning(n),
    extension: _introExtension(n),
    realCase: _introRealCase(unit),
    practiceAction: _introPracticeAction(unit),
    ifThen: _introIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _introReviewPrompt(unit),
  );
}

WillDeepLessonContent _ideoMotorCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _ideoOriginalPoint(unit),
    coreMeaning: _ideoCoreMeaning(n),
    extension: _ideoExtension(n),
    realCase: _ideoRealCase(unit),
    practiceAction: _ideoPracticeAction(unit),
    ifThen: _ideoIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _ideoReviewPrompt(unit),
  );
}


String _introOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final moduleContext = n <= 7
      ? '这一段属于导论前端，重点在说明自愿动作为什么不是天生就会，而是必须先有动作经验。'
      : n <= 19
          ? '这一段属于导论中段，重点在说明动作链为何需要被动运动感、姿态感和视觉等引导性感觉。'
          : n <= 40
              ? '这一段属于“神经支配感”批判的前半段，重点在把行动前态拉回到动作结果图像。'
              : n <= 51
                  ? '这一段属于“努力感并不能证明支配感存在”的反证部分。'
                  : n <= 77
                      ? '这一段属于眼肌、视觉眩晕与空间误判的证据清理部分。'
                      : '这一段属于导论最后收束部分，重点在总结动作观念的真正性质。';
  return '导论单元 ${unit.id} 围绕「${unit.title}」展开。${moduleContext}本单元直接要点是：${unit.oneLiner}它在全章中的作用，是把“意志”从神秘发令，压回到可感觉结果、动作线索与必要时的同意。';
}

String _introCoreMeaning(int n) {
  if (n <= 7) {
    return '这一段对现实训练的意义，是让你承认：身体必须先留下经验痕迹，意志之后才能调用。很多“知道却做不出”不是人格太差，而是动作观念还没真正形成。';
  }
  if (n <= 19) {
    return '这一段真正改变的是你对“执行”的理解：人不是靠一口气把整串动作顶出来，而是靠一步一步的感觉定位继续推进。没有在线反馈，行动就会在中途迷路。';
  }
  if (n <= 40) {
    return '这一段的核心价值，是把行动困难从“我没那股劲”翻译成“动作结果图像不够清楚，或我把问题神秘化了”。这会让训练重新变得可分析。';
  }
  if (n <= 51) {
    return '这一段提醒你：主观上觉得“我很用力”，并不代表你抓住了意志的真正工作。很多时候你抓住的只是全身紧绷，而不是让正确对象在心里稳定留下。';
  }
  if (n <= 77) {
    return '这一段真正训练的是事实盘点能力。很多行动错误不是没有推动力，而是误把替代信号、补偿感觉或空间错觉当成了真实进展。';
  }
  return '这一段帮助你把整章地基抓牢：动作观念不是支配电流的感觉，而是动作可感觉结果的预期。后面所有训练动作，其实都在围绕这一点服务。';
}

String _introExtension(int n) {
  if (n <= 7) return '适用于新习惯、技能学习、晨起流程、发音训练、运动动作和任何“脑子知道但身体不会”的情形。';
  if (n <= 19) return '适用于复杂流程、精细动作、写作流程、演讲、康复和任何中途容易迷失的任务。';
  if (n <= 40) return '适用于启动困难、把任务神秘化、总说“差一股劲”、以及需要把目标改写成具体动作图像的时候。';
  if (n <= 51) return '适用于高 effort 任务、紧张起步、临门一脚、情绪压制和把咬牙硬顶误当成有效努力的时候。';
  if (n <= 77) return '适用于复杂判断、空间动作、进度核对、容易自我误判、以及把“像在前进”误当成真前进的时候。';
  return '适用于整个意志训练模块，是知识学习、现实任务、镜像城和复盘系统的解释底座。';
}

String _introRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 7) return '例如你以为自己已经会开始晨练、会做深蹲、会进入写作状态，但真正一做就发现身体里没有脚本。不是你不想做，而是身体还没把动作线索学会。';
  if (n <= 19) return '例如你能开始写一段话、开始做一组动作，但做到第二三步就散掉。真正丢掉的常不是意愿，而是“我现在在第几步”的感觉定位。';
  if (n <= 40) return '例如你总说“我要开始工作”，但脑中没有清楚结果图像，只有空泛口号；于是你会误以为自己缺一种神秘的内在推力。';
  if (n <= 51) return '例如准备做困难任务时，你先耸肩、憋气、咬牙、顶胸，主观上觉得自己“已经很努力”。但真正该训练的，也许是让任务对象留在心里，而不是让身体先绷住。';
  if (n <= 77) return '例如你以为自己今天已经推进很多，但回头一看，完成的是替代动作、错误方向或主观上“像在努力”的感觉，而不是外部可见结果。';
  return '例如你不再说“我没意志力”，而开始说“我没有抓住动作线索”“我被对抗观念挡住了”“我还没真正说出同意”。这时你才进入可训练的世界。';
}

String _introPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 7) return '今天选一个你总想形成却还不会自然发生的动作，只练最小身体版本 3 次，并刻意记住最明显的本地感觉。';
  if (n <= 19) return '今天选一个 3 步以上的流程动作，每做一步都说出“我现在在第几步”，看自己最容易在哪一步失去引导性感觉。';
  if (n <= 40) return '把今天一个最难启动的任务写成具体动作线索：开始时我会看到什么、碰到什么、第一下要做什么。';
  if (n <= 51) return '在一次困难任务前，观察自己是不是先出现憋气、耸肩、咬牙。把“身体紧绷”与“正确对象”分别记录。';
  if (n <= 77) return '对一个你以为已经推进的任务做一次事实核对：我真正完成了什么？哪些只是主观上像在前进？';
  return '把今天一个最难开始的动作拆成三栏：结果图像、阻滞观念、是否需要 fiat。';
}

String _introIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 7) return '如果我又把“理解了”当成“会做了”，那么我先补一次身体预演，而不是继续讲道理。';
  if (n <= 19) return '如果我在中途开始迷路，那么我先确认“我现在在第几步”，而不是继续硬顶。';
  if (n <= 40) return '如果我又说“我差一股劲”，那么我先把动作改写成具体可感觉的结果图像。';
  if (n <= 51) return '如果我又把全身紧绷误当成有效努力，那么我先放松身体，再确认真正要维持的对象。';
  if (n <= 77) return '如果我又陷入“我好像已经做了”的错觉，那么我先核对外部证据，而不是继续依赖主观感觉。';
  return '如果我又把行动困难看成人格缺陷，那么我先回到“线索—阻滞—同意”三项。';
}

String _introReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 7) return '今天哪一个动作暴露出：我脑中已经知道，但身体里还没有形成可调用的线索？';
  if (n <= 19) return '今天哪个任务不是输在开始，而是输在中间失去了引导性感觉？';
  if (n <= 40) return '今天哪一刻我把一个可分析的行动困难，重新神秘化成了“就是没劲”？';
  if (n <= 51) return '今天哪一次“很用力”的感觉，其实更多是身体紧绷，而不是正确对象站住了？';
  if (n <= 77) return '今天哪一次我误把“像是在前进”当成真正前进？';
  return '今天哪个困难最能用“线索—阻滞—同意”这三项重新解释？';
}

String _ideoOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 5
      ? '这一段属于观念—运动作用的定义层，重点是说明“想到就做”是最简单的意志形式。'
      : n <= 10
          ? '这一段属于“没有冲突观念时动作为何自然发生”的解释层，赖床是经典案例。'
          : n <= 15
              ? '这一段属于“萌芽动作与 fiat 何时出现”的层次。'
              : '这一段属于本节最后的总图景：推动与拦截力量如何在清醒行为中合成。';
  return '观念—运动作用单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在现实训练中的价值，是把行动失败重新解释成“观念是否被冲突观念挡住”。';
}

String _ideoCoreMeaning(int n) {
  if (n <= 5) return '这组内容能解除一个常见误解：不是所有行动都需要隆重决心。很多行为的自然形态，就是在低阻力条件下由观念直接转成动作。';
  if (n <= 10) return '这组内容真正改变的是你对拖延和起步困难的理解。问题往往不是没有目标，而是目标一出现就被相反观念截走了行动机会。';
  if (n <= 15) return '这组内容提醒你：动作即便没完整发生，也常以萌芽形式先出现；而 fiat 往往是在需要解除阻滞时才真正凸显。';
  return '这组内容把意志放回整体动力学：推动观念和拦截观念总在同时作用，所谓“没做”常只是输出被抵消或改道。';
}

String _ideoExtension(int n) {
  if (n <= 5) return '适用于微习惯、任务起步、顺手动作、低门槛行动启动。';
  if (n <= 10) return '适用于赖床、拖延、回避第一步、消息迟迟不发、工作启动困难。';
  if (n <= 15) return '适用于临门退缩、想说不敢说、想做又压住、需要识别 fiat 出现时刻。';
  return '适用于自控、冲动压制、拖延分析、认清行为背后的推动与拦截结构。';
}

String _ideoRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 5) return '例如你看见桌上有灰就顺手掸掉、看见杯子空了就去接水，这些都不是大决战，而是观念低阻力地变成动作。';
  if (n <= 10) return '例如你赖床时并不是一直没有起床观念，而是“太冷、再躺会儿、现在出去很痛苦”等反向台词持续把动作压回去。';
  if (n <= 15) return '例如你想发一条必要但不舒服的消息，手已经点开对话框，脑中已预演内容，可最后又退了出去。动作并非什么都没发生。';
  return '例如你以为自己今天什么都没做，但真实情况可能是：推动与拦截力量相互抵消，最后只剩一声叹气、一次摸手机、一次呼气。';
}

String _ideoPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 5) return '今天刻意记录 3 次“想到就做”的瞬间，并写下：为什么它们没有形成阻滞。';
  if (n <= 10) return '今天对一个最容易拖延的动作，写出它一出现时立刻冒出来的 1 句反向台词。';
  if (n <= 15) return '复盘一件没做成的动作，别只写“没做”，而是写出它以什么萌芽形式已经发生。';
  return '把一个卡住时刻拆成两列：推动动作的观念、拦截动作的观念。';
}

String _ideoIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 5) return '如果我又把一个小动作想得很重，那么我先把它还原成一个低阻力动作。';
  if (n <= 10) return '如果我又被反向台词拖住，那么我先让第一个最小动作发生，再继续评估。';
  if (n <= 15) return '如果我又停在临门一脚，那么我先说出阻挡我的是什么，再给一句简短 fiat。';
  return '如果我又把行动问题看成一团混乱，那么我先把推动与拦截的两组观念分开写出来。';
}

String _ideoReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 5) return '今天哪一个动作本来可以直接发生，却被我额外抬高了门槛？';
  if (n <= 10) return '今天真正挡住行动的，不是缺目标，而是哪一句冲突观念？';
  if (n <= 15) return '今天我需要明确 fiat 的时刻是哪一刻？在那之前动作已经如何萌芽？';
  return '今天哪一次看似“什么都没发生”，其实只是推动与拦截力量在彼此抵消？';
}


WillDeepLessonContent _deliberationCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _deliberationOriginalPoint(unit),
    coreMeaning: _deliberationCoreMeaning(n),
    extension: _deliberationExtension(n),
    realCase: _deliberationRealCase(unit),
    practiceAction: _deliberationPracticeAction(unit),
    ifThen: _deliberationIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _deliberationReviewPrompt(unit),
  );
}

WillDeepLessonContent _decisionCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _decisionOriginalPoint(unit),
    coreMeaning: _decisionCoreMeaning(n),
    extension: _decisionExtension(n),
    realCase: _decisionRealCase(unit),
    practiceAction: _decisionPracticeAction(unit),
    ifThen: _decisionIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _decisionReviewPrompt(unit),
  );
}

String _deliberationOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 2
      ? '这一段属于审议的起点，重点在说明：行动观念一旦被支持与反对的理由包围，就会进入犹豫状态。'
      : n <= 4
          ? '这一段属于审议中段，重点在说明：前景理由不断轮换，但背景理由仍像闸门一样挡住不可逆放电。'
          : '这一段属于审议收束，重点在说明：推动赶紧定下来与害怕不可逆这两股力量如何缠在一起。';
  return '审议单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是把“我只是想不明白”改写成“哪一组理由在前景、哪一组理由仍在后台卡住我”。';
}

String _deliberationCoreMeaning(int n) {
  if (n <= 2) return '这组内容帮助你认清：犹豫不决不是没有行动观念，而是行动观念正被别的理由围住。真正让人不舒服的，是放电迟迟出不去。';
  if (n <= 4) return '这组内容训练你看见“前景 / 背景”的差别：你以为自己是在听当前最响的那条理由，但实际上，真正拦住你的常是背景里没退场的那一组。';
  return '这组内容解释了为什么审议会拖这么久：一方面你想赶快定，另一方面你又怕定下去之后再也回不了头。';
}

String _deliberationExtension(int n) {
  if (n <= 2) return '适用于反复考虑要不要开始、要不要回复、要不要改变关系、要不要离开当前状态的情形。';
  if (n <= 4) return '适用于两边理由都清楚、但总在切换视角、每次都觉得这次要定了却又回去的场景。';
  return '适用于长期悬而未决、拖延决定、怕拍板后后悔、以及总想再看看再说的时候。';
}

String _deliberationRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '例如你知道该开始某件事，但脑中同时浮现“现在开始会很累”“再等状态好一点”“不开始又会继续烂下去”，于是整个人进入犹豫。';
  if (n <= 4) return '例如你今天觉得“必须离开这份工作”，明天又觉得“再观察一下更稳”，两边都不是假理由，问题是后台始终还有另一组没有退出。';
  return '例如你已经被犹豫折磨很久，开始出现一种“坏决定也比没决定强”的冲动，但同时又害怕一旦拍板就永远失去另一条路。';
}

String _deliberationPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '把一个当前最犹豫的问题写成三栏：行动观念、支持它的理由、反对它的理由。先别求解，只求盘点。';
  if (n <= 4) return '对一个长期拖住你的问题，分别写下“前景最响理由”和“背景真正拦住我的理由”。';
  return '今天给一个拖了很久的问题设置 10 分钟审议边界，结束时不要求最终决定，只要求写出：现在更想早点定，还是更怕定错。';
}

String _deliberationIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '如果我又说“我只是还没想清楚”，那么我先把行动观念和对抗理由分开写。';
  if (n <= 4) return '如果我又在前景理由里来回打转，那么我先找出后台那条一直没退场的理由。';
  return '如果我又想靠拖延减轻犹豫，那么我先承认：现在真正拉扯我的是“快点定”和“别定错”。';
}

String _deliberationReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '今天哪个行动观念不是不存在，而是被太多同时在场的理由包围了？';
  if (n <= 4) return '今天哪个背景理由一直没离场，却被我假装没看见？';
  return '今天我更受不了的是继续犹豫，还是害怕一旦决定就不可逆？';
}

String _decisionOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  const contexts = {
    1: '这一段对应理性结账型决定：理由慢慢结清余额，最后几乎不费力地采纳占优方案。',
    2: '这一段对应外因推动型决定：证据未齐，外部偶然因素把人轻轻推向一边。',
    3: '这一段对应内在自动放电型决定：悬置太久后，内在张力突然冲破困局。',
    4: '这一段对应价值尺度突变型决定：外部冲击或内在变调使整套动机突然重排。',
    5: '这一段对应努力压舱型决定：两边都在场时，靠自己把天平压过去。',
  
  'D:D-008': WillDeepLessonContent(
    originalKeyPoint: '这条内容以“麻木男孩”为核心案例：当一个人失去本地动觉与被动运动感觉时，他会对自己的姿势与动作状态丧失直接把握。',
    coreMeaning: '它的重要性在于把“身体知道自己在做什么”这件事从常识变成问题：意志并不是对着一具透明身体发令，身体状态本身必须被感觉到。',
    extension: '适用于动作笨拙、姿态感弱、总觉得自己“在做”却其实没做成、以及长期活在头脑里不在身体里的状态。',
    realCase: '例如你明明觉得自己已经开始、已经投入、已经保持住，但回头一看，动作根本没有像你以为的那样发生。',
    practiceAction: '今天做一次闭眼姿态觉察：闭眼抬起手臂，停 5 秒，再慢慢感知肘、肩、手的相对位置。',
    ifThen: '如果我又以为自己“已经在做”，那么我先回到身体当前的真实姿态与动作感觉。',
    mirrorZone: '感动港',
    reviewPrompt: '今天哪一次我对自己的动作状态判断得太乐观了？',
  ),
  'D:D-046': WillDeepLessonContent(
    originalKeyPoint: 'Ferrier 在这里的关键反驳是：瘫痪中的“用力感”并不必然来自神秘外发支配，而可能来自别处真实发生的肌肉收缩。',
    coreMeaning: '这条内容最有价值的地方，是逼你把“我感觉很用力”与“真正发生了什么”分开。主观 effort 感并不自动证明你抓对了位置。',
    extension: '适用于你觉得自己很努力，但努力总落在错误位置；也适用于把焦虑、皱眉、内耗误当成真正推进。',
    realCase: '例如你坐在桌前觉得自己很辛苦、很绷、很费劲，但回头看，真正的任务一点没动，动的只是肩颈、呼吸和心里的自我施压。',
    practiceAction: '今天对一个“很费劲却没推进”的时刻，写下：真正推进任务的动作是什么？我实际用力又落在了哪里？',
    ifThen: '如果我又觉得“我已经很努力了”，那么我先检查努力到底落在任务，还是只落在紧张。',
    mirrorZone: '努力坡',
    reviewPrompt: '今天哪一次 effort 感很强，但真正推进却很少？',
  ),
  'D:D-065': WillDeepLessonContent(
    originalKeyPoint: '作者在这里通过眼肌麻痹案例指出：看似证明“支配感”的错觉，其实可能来自另一只眼提供的强烈传入感觉。',
    coreMeaning: '这条内容的重要性，是反复提醒你：主观上最直接的解释，未必真是正确解释。很多看似“我就是这样感觉到的”，都可能漏算了别的输入。',
    extension: '适用于过度相信当下直觉解释、把单一主观感受当作全部证据、以及在训练中忽略隐性线索来源的情况。',
    realCase: '例如你会说“我明明知道自己已经转过去了 / 已经做到了 / 已经下决心了”，但真正带给你这种判断的，可能是别的信号，而不是你以为的那个核心机制。',
    practiceAction: '今天挑一个你最笃定的自我解释，问自己：我是不是漏算了别的输入来源？',
    ifThen: '如果我又把第一直觉当成完整解释，那么我先找一条可能被我漏算的输入。',
    mirrorZone: '感动港',
    reviewPrompt: '今天哪一个“我明明就是这样感觉到的”其实可能漏算了别的来源？',
  ),
  'X:X-009': WillDeepLessonContent(
    originalKeyPoint: '作者在这里借爱情与极端案例说明：一种激情可以像“普遍单狂”一样局部接管整个人格。',
    coreMeaning: '这条内容帮助你理解：有些失控并不是全人都坏了，而是某条情感河道局部劫持了系统。',
    extension: '适用于执念、反复回头、关系上头、明知不好却总回去、对象中心化的状态。',
    realCase: '例如你并非在所有方面都失去判断，但只要一碰到某个人、某段关系、某个对象，整套系统就像突然被同一条河拖走。',
    practiceAction: '今天为一个最让你上头的对象写三列：对象本身、旧河道、我想保护的较高对象。',
    ifThen: '如果那个对象又重新点亮整条旧河道，那么我先把较高对象放回眼前，而不是马上回流。',
    mirrorZone: '爆燃区',
    reviewPrompt: '今天哪一个对象最像在局部接管我整套系统？',
  ),
  'W:W-022': WillDeepLessonContent(
    originalKeyPoint: '“孩子与火焰”模型说明：经验会在原本的动作前，提前叫起后果观念，于是新路径开始拦住旧反射。',
    coreMeaning: '训练意志最关键的一件事，不是空喊不要，而是让“后果图像”足够早地出现。',
    extension: '适用于戒拖延、戒分心、戒旧习惯、以及所有“知道后果但总是太晚才想起来”的情况。',
    realCase: '例如你不是不知熬夜会难受，而是“明早难受”的图像总在刷手机已经开始以后才出现；训练要做的是把它提前。',
    practiceAction: '今天把一个常见旧习惯的后果图像写在最早线索旁边，让它比旧动作更早出现一次。',
    ifThen: '如果旧线索又出现，那么我先让后果图像抢先 3 秒出现。',
    mirrorZone: '锻造工坊',
    reviewPrompt: '今天哪一个后果图像如果能更早出现，就足以挡住旧动作？',
  ),
  'W:W-024': WillDeepLessonContent(
    originalKeyPoint: '“狗握爪”模型说明：当旧路径坏掉或不再合用时，系统会在大量失败中慢慢把正确动作的旁路组织出来。',
    coreMeaning: '这条内容特别适合训练心态：你不是一失败就证明没救，而是在试错中给新旁路争取被组织出来的机会。',
    extension: '适用于康复、替代行为、老习惯回潮后重建、以及“明知正确却总走错路”的情境。',
    realCase: '例如你多次试着建立新睡前流程，总是回到旧手机路径；只要你让一次正确的小路径真的跑通，它就开始拥有下次被重用的机会。',
    practiceAction: '今天对一个老问题只争取一次“正确旁路成功跑通”的小样本，不追求整晚都完美。',
    ifThen: '如果旧路径又把我带走，那么我先争取一次旁路成功，而不是要求整场完胜。',
    mirrorZone: '锻造工坊',
    reviewPrompt: '今天哪一次虽然只成功了一小段，但其实是在给旁路争取生长机会？',
  ),
  'F:F-004': WillDeepLessonContent(
    originalKeyPoint: '作者在这里把自由问题压缩到最关键的一问：同样对象当前，我能不能多做一点或少做一点 effort？',
    coreMeaning: '这条内容把争论从大词拉回训练现场：不是抽象谈自由，而是面对一次真实困难时，你是否把 effort 当作一个可练的变量。',
    extension: '适用于失败后自责、宿命化解释、以及训练中反复问“我到底还能不能多坚持一点”的时刻。',
    realCase: '例如你事后常说“我当时根本不可能停下来 / 开始 / 沉住气”。这条内容会要求你更精确：到底是一点都没有空间，还是还有 5 秒空间？',
    practiceAction: '今天对一个刚发生的失败，只写“我下一次最想多争取的 effort 空间是几秒、哪一步”。',
    ifThen: '如果我又想一口气判定“根本不可能”，那么我先只找出下一次能多出的最小空间。',
    mirrorZone: '自由岔路',
    reviewPrompt: '今天我最想训练的，不是抽象自由，而是哪一点最小 effort 空间？',
  ),
  'F:F-010': WillDeepLessonContent(
    originalKeyPoint: '作者在这里把 effort 拉回最深的人格经验：我们会感觉 effort 比能力、财富、好运更像“我之为我”的核心。',
    coreMeaning: '这条内容解释了为什么意志训练会带来自尊、羞耻、庄严感：因为在主观经验里，effort 很像“我把自己给出多少”的尺度。',
    extension: '适用于你在训练里寻找更深动机、以及想理解为什么某些小动作会让你对自己重新有感觉。',
    realCase: '例如有时并不是那件事本身多大，而是你明知道自己本可以继续滑走，却还是把一点自己给出来了，于是整个人都会不一样。',
    practiceAction: '今天记录一次最小但真实的 effort，把它命名成“我把自己给出去的一点”。',
    ifThen: '如果我又觉得训练毫无意义，那么我先回到今天那一点真实 effort。',
    mirrorZone: '自由岔路',
    reviewPrompt: '今天哪一次最像“我把自己给出去了一点”？',
  ),
  'F:F-011': WillDeepLessonContent(
    originalKeyPoint: '本节最后把自由问题落到生活中心：我们每天都在用“同意 / 不同意”的方式回答世界，而不是只用语言。',
    coreMeaning: '这一单元把前面所有内容收束成一句话：意志训练最终是在训练你，面对世界时到底愿不愿意让某些东西成为现实。',
    extension: '适用于你重建人生方向、恢复责任感、重整训练意义、以及把知行合一从口号变成姿态的时候。',
    realCase: '例如你反复问“这一切练了有什么用”，最后会发现：问题不是值不值得争论，而是你每天在用什么态度对世界回答“愿不愿意”。',
    practiceAction: '今天把一个最重要对象写成命令式句子：我愿不愿意让它在今天成为现实一点点？',
    ifThen: '如果我又陷在空想里，那么我先问：今天我愿不愿意让它现实一点点？',
    mirrorZone: '自由岔路',
    reviewPrompt: '今天我用什么具体动作，回答了“我愿不愿意让它成为现实”？',
  ),
};
  return '决定类型单元 ${unit.id} 围绕「${unit.title}」展开。${contexts[n] ?? ''}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是让你学会识别“我是怎么定下来的”，而不只是看最后定了什么。';
}

String _decisionCoreMeaning(int n) {
  switch (n) {
    case 1:
      return '理性型决定的关键不是更热，而是更清。对象一旦被归入熟悉原则，犹豫会像自然结账一样结束。';
    case 2:
      return '外因推动型提醒你：有些决定并不是价值突然清晰，而是疲惫、偶然时机或外部事件替你掀了天平。';
    case 3:
      return '内在自动放电型说明：长期悬置本身也会积压张力，最后哪怕理由未齐，也可能突然向某一边爆出去。';
    case 4:
      return '价值尺度突变型说明：悲伤、恐惧、打击、醒悟会让整套轻重次序突然变化，旧审议直接失效。';
    default:
      return '努力压舱型抓住了最难的一类决定：两种可能都清醒在场，你知道自己正在亲手杀死其中一条未来。';
  }
}

String _decisionExtension(int n) {
  switch (n) {
    case 1:
      return '适用于理性规划、正式选择、长期路线、职业与关系中的原则判断。';
    case 2:
      return '适用于拖久了靠外部推一把才动起来、临时起意、顺势答应或被环境带着走。';
    case 3:
      return '适用于憋久了突然摊牌、突然辞职、突然表白、突然彻底切断旧状态。';
    case 4:
      return '适用于重大打击后的人生转向、恐惧唤醒、良知刺痛、幡然转变。';
    default:
      return '适用于真正艰难的道德选择、损失感很强的取舍、以及需要 effort 才能拍板的关键节点。';
  }
}

String _decisionRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  switch (n) {
    case 1:
      return '例如你把多个工作机会按原则和长期目标反复比对，某天忽然觉得“其实已经够清楚了”，于是平静定下。';
    case 2:
      return '例如你一直拖着不回一封邮件，最后只是因为对方又发了一次、或你刚好在那个页面，就顺势回掉了。';
    case 3:
      return '例如一段关系你犹豫很久，最后在某个普通夜晚突然说“够了”，像一下子洪水决堤。';
    case 4:
      return '例如一次突如其来的打击，让原来轻飘飘的娱乐、面子、拖延全部失去重量，严肃对象一下子占满视野。';
    default:
      return '例如你知道选 A 会失去 B，选 B 会失去 A，两边都真实可爱；最后你几乎是硬把天平压过去。';
  }
}

String _decisionPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  switch (n) {
    case 1:
      return '复盘一件最近做成的决定，写下：它更像“理由自己结账”，还是我硬把自己推过去？';
    case 2:
      return '找一个最近顺势定下来的决定，标出那个真正掀天平的外部因素。';
    case 3:
      return '回想一次“憋久了突然定”的时刻，写出长期积压的张力是怎么形成的。';
    case 4:
      return '记录一次价值尺度突然变化的经历：是什么事件让原来的轻重次序瞬间改写？';
    default:
      return '找一个仍在拉扯的决定，写出：两边都在场时，我最怕失去哪一部分？';
  }
}

String _decisionIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  switch (n) {
    case 1:
      return '如果我已经看清却还在空转，那么我先问：证据是真的没到齐，还是其实已经结账完成？';
    case 2:
      return '如果我又被外部顺势推着做决定，那么我先标记：这次是我选择了，还是时机替我选择了。';
    case 3:
      return '如果我感觉自己快要突然爆出去，那么我先把长期积压的那股张力写出来。';
    case 4:
      return '如果一次打击让我的价值尺度瞬间变化，那么我先用文字固定新排序，不立刻又滑回旧惯性。';
    default:
      return '如果我又来到两边都清醒在场的节点，那么我先承认损失感，再给出明确 fiat。';
  }
}

String _decisionReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  switch (n) {
    case 1:
      return '今天哪一个决定其实已经“够清楚”，只是我还没承认它已结账？';
    case 2:
      return '今天哪个决定主要不是理由赢了，而是外部偶然推了我一把？';
    case 3:
      return '今天有没有什么选择其实已经被我长期积压到接近自动爆发？';
    case 4:
      return '今天是什么让我的轻重次序突然变了？这种变化会不会回退？';
    default:
      return '今天我真正 hardest 的决定里，被我亲手压下去的是哪条未来？';
  }
}

WillDeepLessonContent _effortCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _effortOriginalPoint(unit),
    coreMeaning: _effortCoreMeaning(n),
    extension: _effortExtension(n),
    realCase: _effortRealCase(unit),
    practiceAction: _effortPracticeAction(unit),
    ifThen: _effortIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _effortReviewPrompt(unit),
  );
}

WillDeepLessonContent _pleasureCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _pleasureOriginalPoint(unit),
    coreMeaning: _pleasureCoreMeaning(n),
    extension: _pleasureExtension(n),
    realCase: _pleasureRealCase(unit),
    practiceAction: _pleasurePracticeAction(unit),
    ifThen: _pleasureIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _pleasureReviewPrompt(unit),
  );
}

String _effortOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 2
      ? '这一段属于努力感开头，重点在说明：并不是所有意识都同样容易转成动作。'
      : n <= 4
          ? '这一段属于努力感中段，重点在说明健康意志的比例结构，以及爆发 / 阻塞总框架。'
          : '这一段属于努力感收束，重点在说明为什么理想行动在体验上像沿着最大阻力线发生。';
  return '努力感单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的意义，是把“努力”从咬牙硬顶，改写成对较高对象的维持。';
}

String _effortCoreMeaning(int n) {
  if (n <= 2) return '这组内容说明：有些对象天然更容易引发动作，比如本能、快乐、当下和习惯；而努力常常发生在这些对象之外。';
  if (n <= 4) return '这组内容帮助你识别：问题可能不是没有价值判断，而是动机强弱比例失衡，导致爆发过快或阻塞过强。';
  return '这组内容抓住了 effort 的体验核心：当更理想的对象取胜时，我们主观上会感觉自己在逆着一条更大阻力线前进。';
}

String _effortExtension(int n) {
  if (n <= 2) return '适用于启动困难、长期目标推进、习惯对抗、以及总被眼前近物拉走的时候。';
  if (n <= 4) return '适用于判断自己更偏向爆发型还是阻塞型，并据此调整任务强度和节奏。';
  return '适用于高 effort 任务、克制诱惑、承担义务、以及明明更想轻松却仍选择更值得方向的时候。';
}

String _effortRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '例如你知道应该读书、运动、写作，但手机、床、零食、轻松聊天总比目标更近、更热、更有即时推动力。';
  if (n <= 4) return '例如同样是“意志差”，有人表现为一冲就出去，有人表现为怎么都起不来。问题不一定在价值观，而在动力结构。';
  return '例如你很想继续刷短视频，但同时也知道应该睡觉；最后你把手机放下的瞬间，主观上并不是轻松，而像在逆着一股更顺滑的流。';
}

String _effortPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '今天找一个“更值得但更弱”的对象，只做 30 秒注意锁定：看着它，不切屏，不换任务。';
  if (n <= 4) return '今天判断一次：我当前更像爆发型还是阻塞型？然后为自己选一个更合适的最小任务强度。';
  return '今天做一次“最大阻力线”记录：写下你本来更想顺着哪条轻松路线走，最后又是怎么把自己拉回来的。';
}

String _effortIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '如果我又被更近、更热、更舒服的对象拉走，那么我先让较高对象在心里停留 10 秒。';
  if (n <= 4) return '如果我又不知道自己是该推还是该缩，那么我先判断这是爆发问题还是阻塞问题，再决定动作大小。';
  return '如果我又想顺着最轻松的路线滑走，那么我先承认“现在更难的那条路才更值得”，再做第一步。';
}

String _effortReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '今天哪一个对象其实更值得，却因为太远、太抽象、太不舒服而输给了近物？';
  if (n <= 4) return '今天我的卡点更像爆发失控还是阻塞无力？如果下次再来，我该选更小还是更慢的动作？';
  return '今天哪一个决定最像沿“最大阻力线”发生？我在那一刻维持住的到底是什么对象？';
}

String _pleasureOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 4
      ? '这一段属于快痛动力的开头，重点在说明：快乐痛苦重要，但绝不是唯一动力。'
      : n <= 8
          ? '这一段属于反例与病态吸引部分，重点在说明行动并不总是追求快乐，甚至可能被坏与不快本身吸引。'
          : n <= 15
              ? '这一段属于对 Bain 等快乐理论的批判。'
              : n <= 20
                  ? '这一段属于“成就快感 vs 被追求的快乐”的区分。'
                  : '这一段属于本节收束，重点在把行动的总条件归到“兴趣与注意占据”。';
  return '快痛动力单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是帮助你看清自己到底在追什么、避什么。';
}

String _pleasureCoreMeaning(int n) {
  if (n <= 4) return '这组内容先把地基立住：快痛很强，但不是唯一动力。对象本身、本能、情绪、习惯、事实知觉也都能直接推动动作。';
  if (n <= 8) return '这组内容最能解释那些“明知没意义还会做”的情形：人有时不是在追求快乐，而是在响应一种更怪异、更纠缠的吸引。';
  if (n <= 15) return '这组内容帮助你拆掉“所有行动都为了快乐”这种过度简单的解释，把观念、本能、习惯和固定念头重新放回行动理论。';
  if (n <= 20) return '这组内容最贴近现实训练：很多时候我们不是为了对象快乐本身，而是为了行动一旦释放后那种解除阻断的舒服。';
  return '这组内容最终把行动钥匙交回“兴趣与注意占据”。真正推动你的，往往是那个最能占满意识的对象。';
}

String _pleasureExtension(int n) {
  if (n <= 4) return '适用于纠正“我做任何事都是为了快乐”这类过度简化的自我解释。';
  if (n <= 8) return '适用于冲动消费、强迫性检查、病态模仿、回头闻臭味、反复按痛处等看似荒诞的行为。';
  if (n <= 15) return '适用于理解固定观念、无私冲动、同情和违心行动为什么无法被单一快乐理论解释。';
  if (n <= 20) return '适用于刷手机、拖延、熬夜、游戏、临时逃避、追短平快刺激等高频现实问题。';
  return '适用于注意力训练、任务设计、环境重构、以及任何需要把“我被什么吸住了”看清楚的场景。';
}

String _pleasureRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '例如你会愤怒、脸红、害怕、退缩，这些并不是因为相关动作让你快乐，而是对象本身已经在推动你。';
  if (n <= 8) return '例如你明知道那条短视频已经很无聊，却还是继续滑；或者明知道自己没忘锁门，却还要回去看一眼。';
  if (n <= 15) return '例如你答应了一场其实不想去的聚会，不是因为它快乐、也不一定因为它善，而只是因为当场压力让你没顶住。';
  if (n <= 20) return '例如你以为自己是在“喜欢刷手机”，其实你真正享受的是：任务压力暂时松开、拖延焦虑短暂解除。';
  return '例如当一个念头霸占了你的注意力时，哪怕它并不舒服，它也可能把其他更理智的对象全部挤掉。';
}

String _pleasurePracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天挑一个自动化行为，问自己：它真的是因为快乐才发生，还是对象本身就在推动我？';
  if (n <= 8) return '今天记录一次“明知没必要却还是做了”的小动作，并写下它更像在追求什么。';
  if (n <= 15) return '今天观察一次违心答应、同情出手或固定念头，看看它是否真能用“趋乐避苦”完整解释。';
  if (n <= 20) return '下次分心前先停 10 秒，写出：我是在追这个对象，还是想解除别的难受？';
  return '今天在最容易被吸走的时刻，记录那个最先霸占你注意力的对象是什么。';
}

String _pleasureIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '如果我又把所有行动都解释成“为了快乐”，那么我先问：对象本身是不是也在直接推动我？';
  if (n <= 8) return '如果我又做了一个明知没必要的小动作，那么我先写出它更像是纠缠、固定还是止痛。';
  if (n <= 15) return '如果我又用一个单一理由解释复杂行动，那么我先把快乐、习惯、压力、观念分开看。';
  if (n <= 20) return '如果我又被即时舒服带走，那么我先分开写“对象本身”和“解除不适”这两项。';
  return '如果我又被某个念头抓住，那么我先承认：它现在之所以有力，是因为它占满了注意。';
}

String _pleasureReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天哪一次行动并不是为了快乐，却依然强烈发生了？';
  if (n <= 8) return '今天哪一个荒诞、重复或不必要动作，其实更像一种纠缠性的吸引？';
  if (n <= 15) return '今天哪一次行为，若只用“趋乐避苦”来解释，会明显遗漏重要因素？';
  if (n <= 20) return '今天哪一次我表面在追求快乐，实际上更像在解除阻断或逃离不适？';
  return '今天哪个对象最强地占住了我的注意？它因此把我带向了什么行动？';
}

WillDeepLessonContent _obstructedCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _obstructedOriginalPoint(unit),
    coreMeaning: _obstructedCoreMeaning(n),
    extension: _obstructedExtension(n),
    realCase: _obstructedRealCase(unit),
    practiceAction: _obstructedPracticeAction(unit),
    ifThen: _obstructedIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _obstructedReviewPrompt(unit),
  );
}

String _obstructedOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 2
      ? '这一段属于阻塞型意志的开头，重点在说明：这里的问题不是不知道，而是“我愿意”过不了动作门槛。'
      : n <= 4
          ? '这一段属于阻塞型意志中段，重点在说明现实感、动机效力与见善不能行之间的联系。'
          : '这一段属于阻塞型意志收束，重点在说明 effort 为什么常被召唤来对抗这种无力与迟滞。';
  return '阻塞型单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的作用，是把“明知却不做”重新翻译成可处理的阻滞结构。';
}

String _obstructedCoreMeaning(int n) {
  if (n <= 2) return '这组内容说明：阻塞型问题不是没有价值判断，而是价值判断没有穿过门槛变成动作。对象像在远处，被看到，却碰不到身体。';
  if (n <= 4) return '这组内容真正指出悲剧：高阶对象并未消失，甚至可能被清楚认可，但它们不带“现实感”和“刺痛感”，因此永远进不了主调。';
  return '这组内容把 effort 放回这里：努力不是凭空发明动力，而是帮助较高对象暂时抵住那种迟滞、空洞和熟路牵引。';
}

String _obstructedExtension(int n) {
  if (n <= 2) return '适用于长期拖延、启动困难、任务一大就无力、清楚知道该做却总在原地打转。';
  if (n <= 4) return '适用于理想很多、洞察也不少、但对象总显得远、虚、碰不到自己的情形。';
  return '适用于恢复行动现实感、把理想对象拉近、以及高 effort 起步训练。';
}

String _obstructedRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '例如你知道应该回复邮件、开始报告、去运动，但这些动作像隔着玻璃。你并非不懂，只是动作始终过不了门槛。';
  if (n <= 4) return '例如你对未来的判断其实很清楚，甚至会批评自己的拖延，但那些更好的路总像悬在远处，永远无法刺中当天的身体。';
  return '例如你不是完全没有 effort，而是 effort 总像在迟滞泥地里抬脚。你必须先让对象变近、变真，努力才有抓手。';
}

String _obstructedPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '今天把一个拖住你的任务缩成 2 分钟动作，并补一个可感结果：做完后我会看到什么、桌面会变成什么样？';
  if (n <= 4) return '今天选一个你最认可却最无效的目标，给它写一条“今日版现实化描述”：不是未来意义，而是今天碰到它时我具体要做什么。';
  return '今天做一次“努力不是硬顶”的练习：先让目标对象在心里停 20 秒，再做最小动作，不追求一口气做完。';
}

String _obstructedIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '如果我又觉得“明明知道，却就是动不了”，那么我先缩小动作，再给它一个可感结果图像。';
  if (n <= 4) return '如果我又觉得目标很重要却很远，那么我先把它改写成“今天这 2 分钟我要碰到什么”。';
  return '如果我又开始空耗 effort，那么我先让对象变近、变真，再决定要不要推高强度。';
}

String _obstructedReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 2) return '今天哪一个对象之所以没动，不是因为它不重要，而是因为它过不了动作门槛？';
  if (n <= 4) return '今天哪一个目标我其实认可，却始终没让它获得现实感？';
  return '今天 effort 最应该服务的，不是更用力，而是先让哪个对象变得更近、更真？';
}

WillDeepLessonContent _explosiveCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _explosiveOriginalPoint(unit),
    coreMeaning: _explosiveCoreMeaning(n),
    extension: _explosiveExtension(n),
    realCase: _explosiveRealCase(unit),
    practiceAction: _explosivePracticeAction(unit),
    ifThen: _explosiveIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _explosiveReviewPrompt(unit),
  );
}

String _explosiveOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 4
      ? '这一段属于爆发型意志前半，重点在说明：失控不一定是欲望巨大，也可能是阈值低、刹车弱、通路太通。'
      : n <= 8
          ? '这一段属于病理冲动与强迫观念部分，重点在说明某个念头如何变得过强、过迫切。'
          : '这一段属于爆发型意志后半，重点在说明成瘾、爱情、琐碎强迫等极端案例。';
  return '爆发型单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的作用，是帮助你把“我就是控制不住”拆成可识别的爆发机制。';
}

String _explosiveCoreMeaning(int n) {
  if (n <= 4) return '这组内容提醒你：爆发型问题未必说明你更“真想要”。很多时候只是动作泄洪太快，抑制系统来不及形成。';
  if (n <= 8) return '这组内容把失控进一步分层：有时是阈值低，有时是某个念头过强、过迫切，甚至逼着你去做你明知厌恶的事。';
  return '这组内容帮助你理解极端现实问题：成瘾、爱情执念、琐碎强迫，都可能不是“想清楚后选择”，而是通路被劫持。';
}

String _explosiveExtension(int n) {
  if (n <= 4) return '适用于情绪爆发、冲动回怼、临时消费、短视频失控、想法一来就滑过去的情形。';
  if (n <= 8) return '适用于强迫冲动、侵入性念头、无法抑制的动作、病态“非做不可”的体验。';
  return '适用于成瘾、关系执念、重复性小强迫、以及所有“不是很想，但就是会去做”的场景。';
}

String _explosiveRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '例如你本来只是想看一下消息，结果不知不觉滑进 40 分钟；不是你认真做了决定，而是通路太顺，动作比评估更快。';
  if (n <= 8) return '例如你脑中闪过一个念头，明知荒唐、也不愿意认同它，却还是被迫围着它打转，甚至发展成“必须做点什么才会安静”。';
  return '例如你并不是特别想喝、特别想看、特别想联系那个人，但对象一出现，整个系统就像顺着旧河道自动滑下去。';
}

String _explosivePracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天对一个高风险诱惑做“延迟 90 秒 + 命名冲动”的练习，并记录冲动最高点持续了多久。';
  if (n <= 8) return '今天把一个最常见的侵入性冲动写成一句命名：这不是决定，这是过强念头在逼近。';
  return '今天对一个老通路做“改道练习”：对象一出现时，不立刻跟随，先去做一个固定替代动作。';
}

String _explosiveIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '如果某个冲动又突然变得不可抗，那么我先命名它是“爆发，不是决定”，再延迟 90 秒。';
  if (n <= 8) return '如果我又被某个过强念头逼住，那么我先把它写出来，不立即以动作为它服务。';
  return '如果老通路又自动泄洪，那么我先走替代动作，再决定要不要回到原对象。';
}

String _explosiveReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天哪一次行为更像“泄洪”，而不是清楚选择？最早出现的线索是什么？';
  if (n <= 8) return '今天有没有哪个念头不是更合理，而是更迫切？我有没有把迫切误当成正确？';
  return '今天哪一条老通路最像自己在跑？下次我最早能在哪一秒改道？';
}


WillDeepLessonContent _relationCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _relationOriginalPoint(unit),
    coreMeaning: _relationCoreMeaning(n),
    extension: _relationExtension(n),
    realCase: _relationRealCase(unit),
    practiceAction: _relationPracticeAction(unit),
    ifThen: _relationIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _relationReviewPrompt(unit),
  );
}

String _relationOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 3
      ? '这一段属于本节前半，重点在说明：意志真正结束在“某个观念稳定占上风”，动作只是后续生理执行。'
      : n <= 8
          ? '这一段属于本节中段，重点在说明：带 effort 的注意，就是意志最核心的心理现象。'
          : n <= 11
              ? '这一段属于临床与总结层，重点在说明：自控像把自己绷住，让正确对象不要滑走。'
              : '这一段属于本节最后收束，重点在区分注意与同意，并把“让它成为现实”说成一种独特的意识态度。';
  return '意志与观念关系单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是把意志从“神秘发力”转回到“让哪一个对象在心里真正占上风”。';
}

String _relationCoreMeaning(int n) {
  if (n <= 3) return '这组内容在重新定义意志：意志不是保证动作一定成功，而是保证某个对象在心里被肯定、被扶上前台。动作是否发生，还受后端生理条件限制。';
  if (n <= 8) return '这组内容的核心，是把 effort 放到正确位置：努力不是额外神力，而是把困难对象继续留在心里，让它别被激情、熟路和对抗观念挤走。';
  if (n <= 11) return '这组内容说明，自控很像一种“把自己抓紧”的精神紧绷。很多人不是不懂，而是在困难对象出现时不敢让它留下。';
  return '这组内容最后把“注意”与“同意”分开：注意是让对象进来，同意是让它由可能变成现实、由旁观对象变成我要站在这边的对象。';
}

String _relationExtension(int n) {
  if (n <= 3) return '适用于面对执行失败、身体不配合、动作没发生时，仍想分辨“我到底有没有真正立意”的场景。';
  if (n <= 8) return '适用于情绪来袭、自控困难、理性对象一闪而过就被挤走、需要 effort 去稳住正确对象的时候。';
  if (n <= 11) return '适用于临门退缩、谈话时不敢把关键对象放在心里、以及需要短时间强自控的情形。';
  return '适用于承诺、信念、决定、知行合一，以及一切“我要不要真正站在这个对象这边”的时候。';
}

String _relationRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '例如你很想开始写作、道歉、锻炼，但身体状态、环境或旧通路让动作没成功。这时真正的问题不是“我完全没意志”，而是我有没有让那个对象在心里真正占上风。';
  if (n <= 8) return '例如你在愤怒时知道不该回怼、在深夜知道该停下、在焦虑时知道该回到任务，但那个更高对象一出现就被热情绪挤走。真正困难是把它按住。';
  if (n <= 11) return '例如你在关键场合暂时把自己绷住，不让冲动、害怕或妄想性念头占上风。外表看是安静，内部却是在强力维持某个对象。';
  return '例如你已经看见一个更值得的行动，也愿意注意它，但真正卡住你的是还没“站队”——对象仍停在可想而非可实行的位置。';
}

String _relationPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '今天选一个动作失败的时刻，区分两件事：动作有没有成功，和那个对象有没有真正被我扶到前台。';
  if (n <= 8) return '今天做一次 30 秒注意锁定：当较高对象出现时，不立刻转走，让它在心里完整待满 30 秒。';
  if (n <= 11) return '今天在一个容易失控的时刻，练一次“把自己抓紧”：只做保持，不急着表现得很漂亮。';
  return '今天对一个重要决定写一句明确同意：不是我注意到了它，而是我让它现在对我成为现实。';
}

String _relationIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '如果动作又没成功，那么我先问“对象有没有站稳”，而不是立刻宣判自己没有意志。';
  if (n <= 8) return '如果热情绪又把我拉走，那么我先把正确对象留 10 秒，不急着跟着旧路跑。';
  if (n <= 11) return '如果我又快被带走，那么我先把自己抓紧，先守住，不急着表现。';
  return '如果我又只停在“知道”，那么我先补一句明确同意：让它现在成为现实。';
}

String _relationReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '今天哪一次动作虽然没成功，但我其实已经让正确对象站到了前台？';
  if (n <= 8) return '今天哪个更高对象最难留下？它是被什么热对象或熟路挤走的？';
  if (n <= 11) return '今天哪一刻我真正需要“把自己抓紧”？我是怎么守住的？';
  return '今天哪一个对象，我不只是注意到了，而且真正站到了它这边？';
}


WillDeepLessonContent _freedomCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _freedomOriginalPoint(unit),
    coreMeaning: _freedomCoreMeaning(n),
    extension: _freedomExtension(n),
    realCase: _freedomRealCase(unit),
    practiceAction: _freedomPracticeAction(unit),
    ifThen: _freedomIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _freedomReviewPrompt(unit),
  );
}

String _freedomOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 3
      ? '这一段属于自由意志问题的开端，重点在拆掉“观念互相打架的小代理神话”，并把问题拉回整体思想对象与活动感。'
      : n <= 6
          ? '这一段属于自由意志问题中段，重点在说明：真正要问的不是有没有 effort，而是 effort 的量是否可变、心理学能否判定它。'
          : n <= 9
              ? '这一段属于决定论、宿命论与科学设定的辨析，重点在说明“连续性诱惑”为何强，但又为何不能直接抹掉自由问题。'
              : '这一段属于本节收束，重点在说明：哪怕自由在科学上难判，effort 在人格、道德与宗教生活里仍具有中心地位。';
  return '自由意志单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是帮助你把“我是不是完全没办法”这个问题，从空泛自责拉回到 effort、同意、对象保持与生活立场。';
}

String _freedomCoreMeaning(int n) {
  if (n <= 3) return '这组内容首先纠正你对自由问题的常见误会：自由不是脑中一堆小观念打赢打输，而是整体思想对象如何转向、以及活动感到底意味着什么。';
  if (n <= 6) return '这组内容把争论压缩成一条更可训练的问题：同样的对象当前，我能不能多做一点或少做一点 effort？作者的答案是：严格心理学判不出来。';
  if (n <= 9) return '这组内容说明，决定论之所以迷人，是因为连续性、统一性与科学解释都在拉着我们；但宿命感并不等于决定论证明。';
  return '这组内容最后把自由问题拉回生活层：无论形而上结果如何，effort 作为“我把自己给出去多少”的感觉，仍是人格经验中最深的一层。';
}

String _freedomExtension(int n) {
  if (n <= 3) return '适用于你总把行动困难想成“我脑子里有两个小人在打架”、或总想找一个简单单一“内因”解释决定的时候。';
  if (n <= 6) return '适用于你在失败后问自己“我当时到底能不能多做一点”、或在训练中想知道 effort 到底是不是可加变量的时候。';
  if (n <= 9) return '适用于你在连续失败后滑向宿命感、或在科学理性与道德责任之间来回摇摆的时刻。';
  return '适用于你重新理解“为什么意志训练对我这么重要”、以及为什么 effort 会和自我感、宗教感、使命感纠缠在一起的时候。';
}

String _freedomRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '例如你事后回看一次失败，会说“冲动赢了理性输了”；作者在这里要你看见：真正变化的是整个思想对象如何转向，而不是两个小代理互殴。';
  if (n <= 6) return '例如你想：“那一刻我到底能不能再多坚持 10 秒？”作者会说：从严格心理学角度，你几乎不可能证明那 10 秒是否必然不可能。';
  if (n <= 9) return '例如你连续几次失败后开始说“算了，我就是这样的人，都是旧习惯和环境决定的”。这一段会提醒你：宿命感不是决定论的证明，它只是某种失败经验的主观语气。';
  return '例如你明知从科学上很难证明自由，却仍在关键时刻把 effort 当成“我真正给世界的一点东西”。作者说，这种感觉本身就构成人生经验的重要部分。';
}

String _freedomPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '今天复盘一个决定，把“两个小人在打架”的说法改写成：当时整体对象是什么？它后来如何转向？';
  if (n <= 6) return '对一次失败不要急着判“我根本做不到”，而是只写：当时我还剩哪一点 effort 空间，是我最想训练的？';
  if (n <= 9) return '当你冒出“反正我就这样”的宿命句时，先写一句替代版本：这是宿命感，不是证据。';
  return '今天记录一次你最明显感到“这是我把自己给出去多少”的时刻，不争论哲学，只记录体验。';
}

String _freedomIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '如果我又把困难说成“理性输给冲动”，那么我先问：当时整体对象后来是怎么转向的？';
  if (n <= 6) return '如果我又用“我当时根本不可能”给自己盖章，那么我先只训练多留对象 10 秒。';
  if (n <= 9) return '如果我又滑进宿命感，那么我先把它命名为一种语气，而不是结论。';
  return '如果我又怀疑训练有没有意义，那么我先回到一个问题：今天我愿意把多少自己给出去？';
}

String _freedomReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 3) return '今天哪一次我其实误把复杂转向过程说成了“两个小人在打架”？';
  if (n <= 6) return '今天我最想训练的，不是结论，而是哪一点 effort 空间？';
  if (n <= 9) return '今天我在哪一刻最接近宿命感？它背后真正的失败经验是什么？';
  return '今天哪一次 effort 最像“我把自己给出了一点”？';
}

WillDeepLessonContent _educationCluster(WillUnitIndex unit, String zone) {
  final n = _unitNo(unit.id);
  return WillDeepLessonContent(
    originalKeyPoint: _educationOriginalPoint(unit),
    coreMeaning: _educationCoreMeaning(n),
    extension: _educationExtension(n),
    realCase: _educationRealCase(unit),
    practiceAction: _educationPracticeAction(unit),
    ifThen: _educationIfThen(unit),
    mirrorZone: zone,
    reviewPrompt: _educationReviewPrompt(unit),
  );
}

String _educationOriginalPoint(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  final context = n <= 4
      ? '这一段属于意志教育的开头，重点在说明：动作观念之所以能引出动作，是因为动作先被盲目发生过。'
      : n <= 8
          ? '这一段属于先天通路与运动环部分，重点在说明：感觉到动作的前向路径与闭环机制。'
          : n <= 13
              ? '这一段属于新通路形成部分，重点在说明：经验如何把“结果”变成之后的“原因”。'
              : n <= 21
                  ? '这一段属于动作链学习部分，重点在说明：字母表式的串联动作是如何学会的。'
                  : '这一段属于本节收束，重点在用孩子与火焰、狗握爪等例子说明训练如何改变放电路径。';
  return '意志教育单元 ${unit.id} 围绕「${unit.title}」展开。${context}本单元直接要点是：${unit.oneLiner}它在训练中的价值，是把“如何练成意志”从抽象劝告变成可理解的学习机制。';
}

String _educationCoreMeaning(int n) {
  if (n <= 4) return '这组内容把意志训练的基础说清了：你不能直接训练一个纯概念动作，必须先让身体、感觉、经验里真正发生过，它之后才会被自愿调动。';
  if (n <= 8) return '这组内容说明：先天系统总在朝运动排流，而动作一旦形成闭环就会自己滚。训练的关键不是空想，而是让合适的路径被不断走顺。';
  if (n <= 13) return '这组内容最重要的一点，是“结果图像会反过来成为原因”。这正是训练、模仿、预演、重复为什么有用的机制地基。';
  if (n <= 21) return '这组内容说明复杂动作不是一次想明白，而是靠顺序、链条、正确的下一步逐渐组织起来。';
  return '这组内容把意志教育从理论拉回现实：危险经验会重排通路，成功经验会固定通路，错误路径则会在抑制中慢慢失势。';
}

String _educationExtension(int n) {
  if (n <= 4) return '适用于新习惯、康复、技能学习、动作建立、微习惯预演。';
  if (n <= 8) return '适用于重复训练、自动化流程、启动动作、理解为什么有些动作一旦开始就会自己滚。';
  if (n <= 13) return '适用于 if-then 训练、镜像预演、心理排练、现实任务设计。';
  if (n <= 21) return '适用于复杂任务拆分、连续动作训练、流程学习、晨间流程与工作流程搭建。';
  return '适用于替代行为、风险回避、旧路径改道、训练系统设计和长期习惯重建。';
}

String _educationRealCase(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '例如你想养成晨起写作，但若身体从未留下“坐到桌前—打开文档—写第一句”的经验，意志就没有现成脚本可以调用。';
  if (n <= 8) return '例如你一旦开始刷短视频就会自动往下滑，这也是一种运动环：线索、动作、回馈在不断互相支撑。';
  if (n <= 13) return '例如你不断预演“回到任务第一步”的感觉，久了之后，那个结果图像会比以前更容易把你带回正确动作。';
  if (n <= 21) return '例如你把晨间流程练成“起身—喝水—坐下—打开文档—写标题”，后一步慢慢接上前一步，最后形成连锁。';
  return '例如你小时候被火烫过后，以后看到相似场景会提前出现缩手与谨慎；又比如狗被重新训练后，会改由新路径完成同一指令。';
}

String _educationPracticeAction(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天挑一个想培养的新动作，只练最小身体脚本，不讲大道理，重复 3 次。';
  if (n <= 8) return '今天找一个会自动滚下去的旧动作，画出它的闭环：线索 → 动作 → 回馈。';
  if (n <= 13) return '今天把一个你想建立的新反应做 3 次预演：先想结果，再立刻做第一步。';
  if (n <= 21) return '把一个复杂任务写成 4 步链条，并只练前两步的衔接。';
  return '今天找一个旧通路，设计一个替代路径：旧线索一来，先走新第一步。';
}

String _educationIfThen(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '如果我又想靠“想通了”直接变会做，那么我先补身体脚本。';
  if (n <= 8) return '如果旧动作又自动滚起来，那么我先标出它的闭环，不急着自责。';
  if (n <= 13) return '如果我想建立新反应，那么我先给它一个清楚结果图像，再接第一步。';
  if (n <= 21) return '如果任务太大，我就先练前两步的衔接，而不是要求整串都顺。';
  return '如果旧路径又赢了，那么我先改线索后的第一步，不和整条旧路正面硬碰。';
}

String _educationReviewPrompt(WillUnitIndex unit) {
  final n = _unitNo(unit.id);
  if (n <= 4) return '今天哪个新动作还停留在脑中理解，却没有形成身体脚本？';
  if (n <= 8) return '今天哪一个旧行为最像一个已经成熟的闭环？它靠什么自我维持？';
  if (n <= 13) return '今天我有没有把一个结果图像真的练成“会带动作”的线索？';
  if (n <= 21) return '今天哪一串动作最需要我练“正确的下一步”，而不是硬追求整串完成？';
  return '今天我最值得改造的旧路径是什么？我能先改它的哪一个入口？';
}

int _unitNo(String id) {
  final match = RegExp(r'-(\d+)$').firstMatch(id);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _zone(String code) {
  switch (code) {
    case 'D': return '感动港';
    case 'I': return '起意场';
    case 'A': return '审议庭';
    case 'T': return '裁决塔';
    case 'E': return '努力坡';
    case 'X': return '爆燃区';
    case 'O': return '阻塞谷';
    case 'P': return '诱惑市集';
    case 'R': return '观念神殿';
    case 'F': return '自由岔路';
    case 'W': return '锻造工坊';
    default: return '镜像城';
  }
}

const Map<String, WillDeepLessonContent> _explicit = {
  'D:D-003': WillDeepLessonContent(
    originalKeyPoint: '作者在这里明确提出：自愿运动是“次级功能”，不是“初级功能”。任何真正自愿的动作，都建立在先前非自愿、反射、本能或偶然动作经验之上。',
    coreMeaning: '这意味着人不是一开始就会“靠意志做事”。你之所以能主动做一个动作，是因为这个动作早已在经验中发生过，并在心里留下了可被再次唤起的表象。',
    extension: '它适用于技能学习、行为训练、习惯养成、康复训练，以及一切“我知道但还不会自然做”的场景。它特别能纠正“只要想清楚就会做到”的误解。',
    realCase: '比如第一次做深蹲、第一次练发音、第一次开始晨间流程时，你常常会发现：道理都懂，但身体不会。因为身体还没有形成足够清晰的动作观念。',
    practiceAction: '今天找一个你总想养成却还不自然的动作，只练“第一步的身体版本”3 次，不求完整，只求把动作观念做出来。',
    ifThen: '如果我又把“知道”当成“会做”，那么我先补一次身体层面的预演，而不是继续给自己讲道理。',
    mirrorZone: '感动港',
    reviewPrompt: '今天哪件事暴露了“我脑子里会，但身体里还不会”？我有没有给它一次非完美但真实的预演？',
  ),
  'D:D-020': WillDeepLessonContent(
    originalKeyPoint: '作者在这里收束导论前半：自愿动作至少需要一个能界定“此刻要做哪个动作”的感觉性观念。',
    coreMeaning: '意志不是空的“我要做”，而是一个被感觉图像具体化的“我要做这个”。如果没有这层具体化，意志会变成一团空泛命令。',
    extension: '它适用于起步不清楚、动作模糊、计划过大、总说“我要努力一点”却无从下手的情况。',
    realCase: '比如你说“我要开始工作”，但并不知道第一步是打开哪个页面、看到什么、手要放在哪里、第一句写什么，于是行动根本不会真正开始。',
    practiceAction: '把一个今天要做的动作写成可感觉的版本：开始时会看到什么、手会碰到什么、第一下会做出什么细小动作。',
    ifThen: '如果我又用抽象口号命令自己行动，那么我先把动作改写成可看见、可听见或可感觉的第一步。',
    mirrorZone: '感动港',
    reviewPrompt: '今天哪一个“我要做”其实太空了？我有没有把它改成具体可感觉的动作线索？',
  ),
  'D:D-022': WillDeepLessonContent(
    originalKeyPoint: '传统心理学常主张：除了动作结果图像，还需要一种“神经支配感”来告诉心灵自己正在向哪块肌肉发出能量。',
    coreMeaning: '这一单元的重要性在于：它代表了作者接下来要拆掉的一整个误解——把意志误认成一种神秘的内在发令能量。',
    extension: '它适用于所有“我是不是只差一股劲”“我是不是缺一种内在发令感”的自我叙述。',
    realCase: '很多人说自己“不是不会，就是提不起劲”，仿佛身体里应该存在某个神秘启动电门。作者的工作，就是说明这个想法为什么看似合理，却站不住。',
    practiceAction: '今天当你说“我就是提不起劲”时，暂停 10 秒，改问自己：我现在缺的到底是动作结果图像，还是只是把问题神秘化了？',
    ifThen: '如果我又把问题说成“差一股神秘劲”，那么我先回到动作线索、阻滞观念和最小第一步。',
    mirrorZone: '感动港',
    reviewPrompt: '今天我有没有把一个可分析的问题，误说成“就是没那股劲”？',
  ),
  'D:D-083': WillDeepLessonContent(
    originalKeyPoint: '导论最后的总收束是：使动作成为自愿的，不是“支配思想”，而是动作可感觉效果的预期；而 fiat 的复杂性将进入下一节。',
    coreMeaning: '这是整章地基：你真正能抓住的，不是神秘能量，而是结果图像、动作线索与必要时的同意。',
    extension: '它适用于整个产品里的所有训练：知识卡、任务、if-then、镜像城、复盘，其实都在围绕这一条主线服务。',
    realCase: '当你终于把“我没意志力”翻译成“我没有抓住动作线索、我被冲突观念挡住了、我还没做出 fiat”，你就开始真正拥有可训练的抓手。',
    practiceAction: '写下今天一个最难开始的动作，并把它拆成：结果图像、阻滞观念、是否需要 fiat 三项。',
    ifThen: '如果我又把行动困难看成“人格缺陷”，那么我先问：动作线索是什么？阻滞是什么？我是否需要一个明确同意？',
    mirrorZone: '感动港',
    reviewPrompt: '今天最能代表整章地基的一次行动困难是什么？我有没有把它翻译成“线索—阻滞—同意”的结构？',
  ),
  'I:I-006': WillDeepLessonContent(
    originalKeyPoint: '作者在这里强调：没有冲突观念时，动作观念几乎必然会转成动作。',
    coreMeaning: '这直接改写了“自律失败”的常见解释。很多时候不是你不想做，而是你一想到去做，立刻又被别的观念冲掉了。',
    extension: '它适用于起床、打开文档、发第一条消息、开始运动、收拾桌面、停止刷手机等所有第一步卡住的情境。',
    realCase: '你想站起来去拿水，本来动作几乎会自动发生；但若同时冒出“先等一下”“懒得动”“手头还没看完”，动作就被拦住了。',
    practiceAction: '今天选一个特别小的行动，把环境和内心里的反向观念尽量减到最少，然后观察它是不是更容易自然发生。',
    ifThen: '如果我又卡在第一步，那么我先找出当前最强的那句反向观念，并把环境里的干扰降到最低。',
    mirrorZone: '起意场',
    reviewPrompt: '今天哪个动作本来会自然发生，却被哪一句反向观念拦住了？',
  ),
  'I:I-009': WillDeepLessonContent(
    originalKeyPoint: '赖床案例说明：真正起床往往不是靠一场宏大战斗，而是靠某个念头在没有反向建议时滑入动作。',
    coreMeaning: '这说明很多行动困难并不是靠“更用力想”解决的，而是靠暂时摆脱那些把你锁在原地的对抗性意识。',
    extension: '它适用于赖床、拖延、害怕开始、开工前无限徘徊、总想等状态好了再做的场景。',
    realCase: '你在床上想了一小时“必须起来”，但没起来；后来只是某个瞬间忘了暖和与寒冷，突然坐起，事情就推进了。',
    practiceAction: '明天把起床任务缩成“先坐起来 10 秒”，不要在床上做价值评判，只观察反向观念何时变弱。',
    ifThen: '如果我又在床上展开一场巨大的心理大战，那么我先只要求自己坐起来，不继续讨论人生。',
    mirrorZone: '起意场',
    reviewPrompt: '今天有没有哪个任务像赖床一样，被我用过度清醒的对抗意识拖住了？',
  ),
  'I:I-015': WillDeepLessonContent(
    originalKeyPoint: 'fiat 往往出现在需要解除阻滞时，而不是每一个动作都自带的一股“额外力”。',
    coreMeaning: '真正的“我决定了”常常发生在你必须穿过一个卡点的时候。若没有阻滞，很多动作根本不需要隆重决心。',
    extension: '它适用于任务开头、临门退缩、想做但被顾虑拦住的时刻，也适用于理解为什么有些决定体验特别重。',
    realCase: '你平常走路、拿杯子、打开电脑并不需要大喊一声“我命令自己”；但在你要发一封难发的邮件、去面对一个困难任务时，明确同意才会突出地出现。',
    practiceAction: '今天找一个你明确感到“要跨过去”的瞬间，把它记录为一次 fiat：当时你在穿过什么阻滞？',
    ifThen: '如果我又停在临门一脚，那么我先把阻滞说出来，再给自己一句明确同意。',
    mirrorZone: '起意场',
    reviewPrompt: '今天我真正需要 fiat 的时刻是哪一刻？它解除的是哪一种阻滞？',
  ),
  'E:E-003': WillDeepLessonContent(
    originalKeyPoint: '作者在这里指出：努力的正常领域，恰恰是让那些非本能、非习惯、较远较抽象但更值得的动机取得主导。',
    coreMeaning: '你会感觉 effort，不是因为你突然拥有了额外神秘力量，而是因为你正试图让较高对象抵住较近、较热、较舒服的对象。',
    extension: '它适用于自律、长期目标推进、克制即时诱惑、以及一切“我知道更值得，但身体不想去”的时候。',
    realCase: '比如晚上你更想继续刷手机，但也知道应该睡觉；睡觉这件事更值得，却更远、更冷、更不刺激，因此常需要 effort。',
    practiceAction: '今天对一个“更值得但更弱”的对象做一次 30 秒注意锁定，不允许自己立刻切去找更舒服的替代物。',
    ifThen: '如果我又被更近更热的对象拉走，那么我先让那个更值得的对象在心里多停 10 秒。',
    mirrorZone: '努力坡',
    reviewPrompt: '今天哪一个对象更值得，却因为太远、太抽象、太不舒服而输给了近物？',
  ),
  'E:E-005': WillDeepLessonContent(
    originalKeyPoint: '作者在这里给出 effort 最著名的体验定义：理想行动往往像沿着“最大阻力线”发生。',
    coreMeaning: '你在 effort 时主观上不会觉得自己顺流而下，而会感觉自己在逆着一条更省力、更滑、更舒服的路往回拉。',
    extension: '它适用于停止刷手机、压住情绪、承受义务、困难启动、凌晨按时睡觉等典型自律情境。',
    realCase: '比如你已经拿起手机准备继续刷，但最后还是把手机扣下、去洗漱睡觉。那一刻的主观体验往往不是轻松，而像在逆流。',
    practiceAction: '今天记录一次最明显的“最大阻力线”时刻：更轻松的路是什么？你最后为什么没有走它？',
    ifThen: '如果我又想顺着最省力的路滑走，那么我先承认“更难的那条现在才更值得”，再只做第一步。',
    mirrorZone: '努力坡',
    reviewPrompt: '今天哪一次行动最像沿最大阻力线发生？那一刻真正被你维持住的对象是什么？',
  ),
  'P:P-003': WillDeepLessonContent(
    originalKeyPoint: '作者在这里明确反对“所有行动都只是趋乐避苦”这一说法，指出本能、情绪和对象本身也会直接推动动作。',
    coreMeaning: '这能纠正一个常见误解：并不是你做任何事都因为它快乐。很多行为在发生时，是对象本身就在推你。',
    extension: '适用于愤怒、害怕、脸红、逃避、自动反应，以及所有“我根本没来得及权衡快乐”的场景。',
    realCase: '比如你突然生气回怼、看到危险立刻躲开，这些都不靠预想快乐来启动。',
    practiceAction: '今天挑一次自动反应，问自己：这一刻真的是因为快乐才发生，还是对象本身已经在推动我？',
    ifThen: '如果我又把一切都解释成“为了快乐”，那么我先检查对象本身是不是已经足以推动动作。',
    mirrorZone: '诱惑市集',
    reviewPrompt: '今天哪一次行动明显不是为了快乐，却依然很强地发生了？',
  ),
  'P:P-017': WillDeepLessonContent(
    originalKeyPoint: '这一段是本节最贴近现实训练的一条：很多时候我们不是在追对象本身，而是在追“阻断解除后的舒服”。',
    coreMeaning: '这能直接解释拖延、刷手机、临时逃避、熬夜等高频问题：你以为自己在想要那个对象，其实更可能是在想停掉此刻的不适。',
    extension: '适用于短视频、游戏、零食、发呆、闲逛、无意义切换任务、迟迟不开始等场景。',
    realCase: '你不是非要看第 18 条短视频，你更像是在借它逃离那份报告、那条消息、那段关系里的难受。',
    practiceAction: '下次分心时先写一句：我现在想得到的是这个对象，还是想解除别的难受？',
    ifThen: '如果我又被即时舒服吸走，那么我先把“对象本身”和“解除不适”分开写出来。',
    mirrorZone: '诱惑市集',
    reviewPrompt: '今天哪一次我看似在追求快乐，其实更像在止痛或避开不适？',
  ),
  'P:P-022': WillDeepLessonContent(
    originalKeyPoint: '作者最后把行动总条件概括为“兴趣”：真正推动你的，往往是那个最能占据注意力的对象。',
    coreMeaning: '行动的钥匙不只在快乐，而在“什么占住了我”。只要某对象在意识里稳稳站住，它往往就会把相应行动一起带出来。',
    extension: '适用于任务设计、环境设计、注意训练、任务切换、诱惑管理，以及任何“我老被某件事吸走”的问题。',
    realCase: '比如当手机亮起时，它并不一定最快乐，但它最会占住你的注意，于是它在行为上胜出。',
    practiceAction: '今天在最容易被吸走的时刻，记录那个最先霸占你注意力的对象是什么，以及它把你带向了什么动作。',
    ifThen: '如果我又被某个对象整块吸走，那么我先承认：它现在有力，是因为它占满了我的注意。',
    mirrorZone: '观念神殿',
    reviewPrompt: '今天哪个对象最成功地占住了我的注意？我有没有在更早的时候看见它？',
  ),
  'O:O-001': WillDeepLessonContent(
    originalKeyPoint: '作者在这里把阻塞型意志的地基说清：问题不是没有判断，而是对象没有刺破意志门槛。',
    coreMeaning: '你之所以“明知却不做”，常常不是因为缺观念，而是因为观念没有现实感，碰不到身体。',
    extension: '适用于长期拖延、空转、无力启动、任务总显得很远很虚的情形。',
    realCase: '你知道该回消息、该开始写、该去运动，但这些对象像悬在远处，完全没有推进身体的力量。',
    practiceAction: '把今天一个最重要却最无效的任务，改写成“现在这 2 分钟我要碰什么、做什么、看到什么”。',
    ifThen: '如果我又觉得“我明明知道却动不了”，那么我先把目标变成一个今天能碰到的动作对象。',
    mirrorZone: '阻塞谷',
    reviewPrompt: '今天哪个目标我其实认可，却始终没有获得现实感？',
  ),
  'O:O-004': WillDeepLessonContent(
    originalKeyPoint: '作者在这里把阻塞型意志的悲剧说到最深：并不是看不见更好，而是更好永远进不了主调。',
    coreMeaning: '许多“失败者”不是道德知识不足，而是较高对象一直在后台低鸣，却从不真正掌舵。',
    extension: '适用于理想很高、洞察很多、也常自责，却始终无法形成行动主旋律的情形。',
    realCase: '你很会分析自己，也知道该走哪条路，但真正每天在驱动你的，还是低级熟路和近物。',
    practiceAction: '今天把一个后台低鸣已久的理想目标写成“今天主调版本”，只允许自己围绕它做 1 个动作。',
    ifThen: '如果高阶目标又退到后台，那么我先让它获得一个今天就能兑现的小主调动作。',
    mirrorZone: '阻塞谷',
    reviewPrompt: '今天哪个更好的对象一直在后台低鸣，却始终没成为主调？',
  ),
  'X:X-001': WillDeepLessonContent(
    originalKeyPoint: '作者开头就提醒：爆发型不必然说明欲望更真、更大，很多时候只是扳机太轻。',
    coreMeaning: '爆发型问题首先要学会去羞耻化：很多失控不是因为你内在更坏，而是因为动作放电太快。',
    extension: '适用于情绪爆发、顺手刷手机、控制不住回嘴、冲动消费等典型快放电场景。',
    realCase: '你本来只是想看一眼消息，最后却顺流滑进长时间分心；这更像阈值低，而不是深思熟虑后的选择。',
    practiceAction: '今天对一个常见快放电行为做“延迟 30 秒 + 命名它是泄洪”的练习。',
    ifThen: '如果我又要瞬间滑过去，那么我先说：这是快放电，不是决定。',
    mirrorZone: '爆燃区',
    reviewPrompt: '今天哪一次最像扳机太轻？我有在最早一秒认出它吗？',
  ),
  'X:X-006': WillDeepLessonContent(
    originalKeyPoint: '这一段代表爆发型的强迫观念层：有些冲动不是更有道理，而是更有逼迫性。',
    coreMeaning: '在这种结构里，最重要的不是和冲动讲理，而是先识别：迫切 ≠ 正确。',
    extension: '适用于侵入性念头、反复想伤害/检查/确认、越不想做越被逼近的体验。',
    realCase: '你明知道自己并不赞同那个念头，但它像逼近的警报一样要求你立刻做点什么。',
    practiceAction: '今天对一个逼迫性念头练习一句外显命名：这是过强观念，不是我的决定。',
    ifThen: '如果某个念头又强迫我立刻动作，那么我先把它写出来，而不是立刻服务它。',
    mirrorZone: '爆燃区',
    reviewPrompt: '今天哪个念头最像“更迫切”而不是“更正确”？',
  ),
  'X:X-010': WillDeepLessonContent(
    originalKeyPoint: '作者通过极端案例提醒：很多所谓“我就是想要”，其实更接近被旧通路劫持。',
    coreMeaning: '成瘾或执念最值得训练的地方，是识别自动河道，而不是反复道德审判。',
    extension: '适用于老习惯回潮、固定对象重复追逐、明知后果却仍会回去的场景。',
    realCase: '你并不总是真的想喝、想联系、想继续看，但对象一出现，旧河道就把你带走。',
    practiceAction: '今天为一条老通路设计一个固定替代动作，并在对象一出现时优先执行替代动作。',
    ifThen: '如果旧河道又被激活，那么我先走替代动作，再决定要不要回到原对象。',
    mirrorZone: '爆燃区',
    reviewPrompt: '今天哪一条旧通路最像自己在跑？我有没有成功让它改道哪怕一次？',
  ),
  'A:A-002': WillDeepLessonContent(
    originalKeyPoint: '审议的中段提醒你：你并不是只受眼前最响的理由支配，真正把放电挡住的，常是后台那组没有退场的背景理由。',
    coreMeaning: '这会改变你对“我已经想过了”的理解。很多犹豫不是因为没想，而是因为真正拦住你的那条背景理由始终还在。',
    extension: '适用于长期犹豫、总觉得今天差一点就要决定、但明天又回到原地的情形。',
    realCase: '你白天一直告诉自己应该开始、应该回复、应该离开；但背景里那句“再等等、再看看、定了就回不去了”一直没退场。',
    practiceAction: '今天复盘一个犹豫点，分别写下：前景最响理由是什么？背景真正挡住我的是什么？',
    ifThen: '如果我又在最响的理由里来回打转，那么我先把后台那句一直没退场的话写出来。',
    mirrorZone: '审议庭',
    reviewPrompt: '今天哪个问题里，真正挡住我的其实是背景理由，而不是前景理由？',
  ),
  'A:A-005': WillDeepLessonContent(
    originalKeyPoint: '审议后段抓住两股缠绕一切决定的恒常力量：一股想赶紧结束犹豫，一股又害怕一旦定下就不可逆。',
    coreMeaning: '很多拖延决定并不是因为看不见，而是因为“快定吧”和“别定错”同时都很强。',
    extension: '适用于关系、工作、重大选择、长期悬置和反复拖延拍板。',
    realCase: '你已经烦透了继续拖着，但又害怕一旦真的回复、辞职、拒绝、表白，就再也回不到原位。',
    practiceAction: '对一个拖很久的问题，只写两句：我现在更受不了继续犹豫，还是更怕一旦拍板就回不了头？',
    ifThen: '如果我又因为“怕定错”继续拖，那么我先承认：现在同时拉我的，其实还有“赶紧定下来”的冲动。',
    mirrorZone: '审议庭',
    reviewPrompt: '今天我更怕的是继续犹豫，还是一旦决定后的不可逆？',
  ),
  'T:T-001': WillDeepLessonContent(
    originalKeyPoint: '理性型决定的关键，不是更戏剧化，而是理由慢慢自己结账。',
    coreMeaning: '这类决定看起来像“没有用力”，但它并不浅，它只是依赖更清楚的原则与分类。',
    extension: '适用于职业、学习、关系和任何需要原则先于情绪的选择。',
    realCase: '你不断比较两条路，最后某天发现：其实证据已经够了，我只是在拖承认。',
    practiceAction: '找一个最近的决定，问自己：这件事其实已经结账了吗？我是不是只是还没承认它已清楚？',
    ifThen: '如果我已经看清却还在空转，那么我先把“我其实已经知道”的那一句写出来。',
    mirrorZone: '裁决塔',
    reviewPrompt: '今天哪个问题其实已足够清楚，只是我还没允许自己拍板？',
  ),
  'T:T-005': WillDeepLessonContent(
    originalKeyPoint: '努力压舱型决定，是五种里最苦的一类：两边都真实在场，而你知道自己正在亲手压掉其中一条未来。',
    coreMeaning: '这类决定的 effort 不在于更吵，而在于更清醒：你知道自己失去什么，却仍要把天平压过去。',
    extension: '适用于艰难取舍、道德选择、高代价承诺、以及知行真正冲到一条线上的时刻。',
    realCase: '你明知继续轻松更舒服，放弃某条路也会失去很多，但还是在清醒中给出了那句 fiat。',
    practiceAction: '对一个艰难选择写下：我压下去的到底是哪条未来？它为什么仍然值得我郑重哀悼？',
    ifThen: '如果我来到两种可能都清醒在场的节点，那么我先承认损失，再做决定。',
    mirrorZone: '裁决塔',
    reviewPrompt: '今天哪一个决定最像“我清楚知道自己正在压掉一条未来”？',
  ),

  'R:R-003': WillDeepLessonContent(
    originalKeyPoint: '作者在这里明确说出：带 effort 的注意，就是意志所含的一切。意志的核心动作，不是神秘发力，而是把困难对象钉在心前。',
    coreMeaning: '这条内容几乎可以看成整个模块的中心轴：真正的 effort，不是制造额外能量，而是让正确对象别被热情绪、熟路和对抗观念挤掉。',
    extension: '它适用于拖延、自控、情绪来袭、深夜停不下来、该做却不断滑走的场景。',
    realCase: '例如你知道该停下手机、该开始任务、该先沉默 30 秒，但那个对象一出现就被更热、更近的对象顶走。真正困难不是体力，而是让它留下。',
    practiceAction: '今天做一次 30 秒“带 effort 的注意”：把正确对象写出来，盯住它 30 秒，不允许自己立刻转走。',
    ifThen: '如果我又被热对象拉走，那么我先让较高对象在心里多留 10 秒。',
    mirrorZone: '观念神殿',
    reviewPrompt: '今天哪一个正确对象最难留下？它是被什么挤走的？',
  ),
  'R:R-008': WillDeepLessonContent(
    originalKeyPoint: '作者在这里说明：一旦困难对象被按住并留在意识中心，它会慢慢召来自己的联想，改变整个意识气候，行动也会随之改道。',
    coreMeaning: '意志最难的不是一路把事情推完，而是先守住那个会改写整场局面的对象。很多时候，后面都是它自己长出来的。',
    extension: '适用于启动困难、关系沟通、冲突压住、长期目标回归。',
    realCase: '比如你先守住“先写 5 分钟”“先别回怼”“先把这封邮件发出去”，后面的动作和情绪会慢慢自己跟上。',
    practiceAction: '今天给一个重要对象 1 分钟不被打断的停留时间，观察后续联想是否开始变。',
    ifThen: '如果我又想靠立刻完成来证明意志，那么我先只做“把关键对象留住”这一步。',
    mirrorZone: '观念神殿',
    reviewPrompt: '今天哪个对象一旦被我留住，后面整场局面就开始变了？',
  ),
  'W:W-002': WillDeepLessonContent(
    originalKeyPoint: '作者在这里指出：意志教育的核心问题，是动作观念如何引出动作；但在此之前，动作必须先被盲目地发生过。',
    coreMeaning: '这条内容把“训练意志”从说教拉回机制：你不是先有完美意志再去做，而是在做的过程中，慢慢把可调用的动作观念练出来。',
    extension: '适用于习惯养成、晨间流程、康复训练、技能学习和任何“知道很多却起不来”的情况。',
    realCase: '例如你想形成晨起写作习惯，不是先等自己彻底想通，而是先真的走一遍起身、喝水、坐下、打开文档这条最小脚本。',
    practiceAction: '今天给一个想培养的新动作做 3 次最小预演，不求完整，只求身体留下脚本。',
    ifThen: '如果我又想先把一切想透再动，那么我先做最小身体预演。',
    mirrorZone: '锻造工坊',
    reviewPrompt: '今天我为哪个新动作真的留下了第一条身体脚本？',
  ),
  'W:W-009': WillDeepLessonContent(
    originalKeyPoint: '作者在这里提出：新通路形成，来自前向放电对后方细胞的抽排；经验会使原本不通的联系慢慢可通。',
    coreMeaning: '你每次重复一个正确顺序，不只是“又做了一遍”，而是在让一条以后更容易出现的新路径变得更深。',
    extension: '适用于 if-then 训练、替代行为、任务启动脚本、戒断旧通路。',
    realCase: '例如你每次都让“看见手机 → 先放远 10 秒 → 再决定要不要拿”成功发生一次，就在为新路径挖河道。',
    practiceAction: '今天把一个旧线索接上一个新第一步，并重复 3 次。',
    ifThen: '如果老线索又出现，那么我先走新第一步，不让旧路径自动接管。',
    mirrorZone: '锻造工坊',
    reviewPrompt: '今天我有哪一次真的在给新路径挖河道？',
  ),
  'W:W-021': WillDeepLessonContent(
    originalKeyPoint: '作者在这里说明：联想通路通常按前向方向形成，因此倒背字母表必须重新学一条反向路。',
    coreMeaning: '这条内容非常适合现实训练：你不能只喊“不要走旧路”，而要明白旧路是顺的，新路要重新组织。',
    extension: '适用于改习惯、戒拖延、替代反应训练、把旧自动路径改成新路径的所有场景。',
    realCase: '例如你每晚都自动刷手机，这不是一句“别刷了”就能逆转；你必须重新学会“疲劳 → 洗漱 → 上床”的反向新链条。',
    practiceAction: '今天挑一条最自动的旧路径，写出它的反向新链条，并只练前两步。',
    ifThen: '如果旧路径又自动跑出来，那么我先练新链条的第一步和第二步，不要求一次全换。',
    mirrorZone: '锻造工坊',
    reviewPrompt: '今天哪条旧路最顺？我有没有开始把反向新路真正练出来？',
  ),
};
