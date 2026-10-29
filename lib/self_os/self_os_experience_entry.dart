import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_repository.dart';
import 'self_os_principles.dart';
import 'self_os_principle_link.dart';
import 'self_os_experience_page.dart';
export 'self_os_principle_link.dart';

class SelfOsExperienceEntry extends StatefulWidget {
  const SelfOsExperienceEntry({super.key, required this.link, this.repository});
  final OsPrincipleLink link;
  final SelfOsRepository? repository;
  @override
  State<SelfOsExperienceEntry> createState() => _SelfOsExperienceEntryState();
}

class _SelfOsExperienceEntryState extends State<SelfOsExperienceEntry> {
  late final _repo = widget.repository ?? SelfOsRepository();
  late final _load = _read();
  Future<Widget> _read() async {
    final cases = await _repo.loadCases();
    final profile = await _repo.loadProfile();
    final c = cases.where((c) => c.id == widget.link.caseId).firstOrNull;
    if (c == null) throw const FormatException('原案例已删除');
    final p = profile.principles
        .where((p) => p['id'] == widget.link.principleId)
        .firstOrNull;
    final a = SelfOsPrinciples.applications(c)
        .where((a) =>
            a['principleId'] == widget.link.principleId &&
            a['triggerId'] == widget.link.triggerId &&
            a['caseId'] == widget.link.caseId &&
            a['stale'] != true &&
            a['atT2'] == null &&
            !['declined', 'cancelled'].contains(a['exposureStatus']))
        .firstOrNull;
    if (profile.experienceSettings['remindersEnabled'] != true ||
        p == null ||
        a == null ||
        a['round'] != c.round ||
        a['principleVersion'] != SelfOsPrinciples.normalize(p)['version'] ||
        SelfOsPrinciples.unavailable(p, cases, currentCaseId: c.id) != null)
      throw const FormatException('这条提示已暂停、修订或失去来源，请回案例重新核对');
    SelfOsPrinciples.recordExposure(c, osText(a['id']), 'opened');
    await _repo.saveCase(c);
    return SelfOsExperiencePage(
        value: c,
        profile: profile,
        history: cases,
        repository: _repo,
        initialApplicationId: osText(a['id']));
  }

  @override
  void dispose() {
    if (widget.repository == null) _repo.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        return Scaffold(
            appBar: AppBar(title: const Text('经验提示')),
            body: Center(
                child: snapshot.hasError
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('提示目前不可用，原记录已保留。可以返回“成为自己”重新打开案例核对。'))
                    : const CircularProgressIndicator()));
      });
}
