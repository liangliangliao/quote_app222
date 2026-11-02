import 'model.dart';

/// Internal validation details go back to the bounded repair prompt. The
/// workbench explains what is recoverable, without exposing schema paths/IDs
/// or blaming the person's account of their experience.
String analysisFailureMessage(Object error) {
  if (error is! MirrorProblem) return '这一步暂时没有完成，前面的分析已保存。可以重试当前这一步。';
  return switch (error.code) {
    'source_reference_invalid' => 'AI 整理这一步时有一处引用没有对上，前面的分析已保存。可以直接重试这一步。',
    'response_shape_invalid' ||
    'model_json_invalid' ||
    'clarity_style_invalid' =>
      'AI 这次返回的内容格式不完整，前面的分析已保存。可以直接重试这一步。',
    'quality_format_invalid' => 'AI 暂时没有完成建议复核，前面的分析已保存。可以直接重试这一步。',
    _ => error.message,
  };
}
