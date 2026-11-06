// Legacy diagnostic formatter. No widgets or routes display request usage.
String aiHistoricalOutputPolicy(Map<String, dynamic> row) {
  final raw = row['budget'];
  final budget = raw is Map ? raw : const {};
  if (budget['policy'] == 'service_capacity') {
    final capacity = budget['provider_required_capacity'];
    return capacity == null ? '应用输出上限：未设置' : '应用输出上限：未设置 · 协议必填的模型容量 $capacity';
  }
  final historical = budget['effective'];
  return historical is num && historical > 0
      ? '历史请求的输出上限：$historical'
      : '历史请求的输出上限：未记录';
}
