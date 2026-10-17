import '../domain/model.dart';
import 'protocol.dart';

/// UI-sized passes share the same Case and permission grant. The full workflow
/// remains available for batch callers; entering a case no longer starts it.
enum WorkbenchPass { understand, reasons, cognition, routes }

List<AnalysisStage> stagesForPass(WorkbenchPass pass) => switch (pass) {
      WorkbenchPass.understand => [
          AnalysisStage.understand,
          AnalysisStage.wants
        ],
      WorkbenchPass.reasons => [
          AnalysisStage.options,
          AnalysisStage.motives,
          AnalysisStage.reappraise
        ],
      WorkbenchPass.cognition => [
          AnalysisStage.cognition,
          AnalysisStage.challenge
        ],
      WorkbenchPass.routes => [AnalysisStage.routeAssessment],
    };

List<AnalysisStage>? requestedPass(Json options) {
  final value = options['workbenchPass'];
  if (value == null) return null;
  final pass = WorkbenchPass.values.where((p) => p.name == value).firstOrNull;
  if (pass == null) throw const MirrorProblem('无法识别本次分析范围');
  final stages = stagesForPass(pass);
  final resume = options['resumeAt'];
  if (resume == null) return stages;
  final index = stages.indexWhere((s) => s.name == resume);
  if (index < 0) throw const MirrorProblem('重试阶段不属于本次分析范围');
  return stages.sublist(index);
}

WorkbenchPass? passForStep(int step) => switch (step) {
      0 => WorkbenchPass.understand,
      1 => WorkbenchPass.reasons,
      2 => WorkbenchPass.cognition,
      3 => WorkbenchPass.routes,
      _ => null,
    };

bool stepHasAnalysis(CaseFile file, int step) => switch (step) {
      0 => file.latest(NodeKind.understanding) != null,
      1 => file.current(NodeKind.motive).isNotEmpty,
      2 => file.current(NodeKind.reframe).isNotEmpty,
      3 => file.current(NodeKind.route).isNotEmpty &&
          file.current(NodeKind.route).every((route) => file
              .current(NodeKind.routeFit)
              .any((fit) => fit.text('routeId') == route.id)),
      _ => true,
    };
