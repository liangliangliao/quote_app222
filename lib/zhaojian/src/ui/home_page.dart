import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';
import 'decide_page.dart';
import 'growth_page.dart';
import 'hypothesis_page.dart';
import 'log_page.dart';
import 'pending_page.dart';
import 'widgets.dart';

/// 照见首页：因果链主轴、下一步、五个入口。
class ZhaojianHomePage extends StatelessWidget {
  const ZhaojianHomePage({super.key, required this.controller});

  final ZhaojianController controller;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  String _nextStep() {
    final int pending = controller.pending.length;
    if (pending > 0) return '有 $pending 张牌还没开：现场发生后，到「未开的牌」开牌。';
    if (controller.decisions.isEmpty) return '拿一个真实、正在纠结的选择，走一遍「选择」。';
    if (controller.hypotheses.isEmpty) {
      return '写下一条关于自己的假设（主线），之后记录行为时标注它表达了哪条主线。';
    }
    return '保持节奏：做新的选择、开牌、记录行为，让对自己的认识再校准一圈。';
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: zCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icon, color: zAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: zInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: zMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: zMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(ZCopy.title),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              const ZNote(ZCopy.chainLine),
              const ZNote(ZCopy.principle),
              const SizedBox(height: 6),
              ZItem(child: Text(_nextStep())),
              const SizedBox(height: 10),
              _tile(
                context,
                icon: Icons.balance_outlined,
                title: '选择',
                subtitle: '补全动机 · 体验卡 · 天平 · 封存预测',
                page: DecidePage(controller: controller),
              ),
              _tile(
                context,
                icon: Icons.style_outlined,
                title: '未开的牌',
                subtitle: '现场速查 · 开牌 · 自知分',
                page: PendingPage(controller: controller),
              ),
              _tile(
                context,
                icon: Icons.edit_note_outlined,
                title: '行为记录',
                subtitle: '做了什么 · 事后反应 · 身体信号',
                page: LogPage(controller: controller),
              ),
              _tile(
                context,
                icon: Icons.timeline_outlined,
                title: '主线与假设',
                subtitle: '字母拼成词：支持与反驳',
                page: HypothesisPage(controller: controller),
              ),
              _tile(
                context,
                icon: Icons.insights_outlined,
                title: '成长回顾',
                subtitle: '命中率 · 谁胜出 · 自由感 · 想象深度',
                page: GrowthPage(controller: controller),
              ),
              const SizedBox(height: 8),
              const ZNote(ZCopy.redLine),
            ],
          ),
        );
      },
    );
  }
}
