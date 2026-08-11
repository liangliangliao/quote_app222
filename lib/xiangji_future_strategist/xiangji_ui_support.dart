import 'package:flutter/material.dart';

import 'xiangji_models.dart';

class XiangjiPalette {
  const XiangjiPalette._();

  static const Color ink = Color(0xFF17241F);
  static const Color pine = Color(0xFF245C4A);
  static const Color mist = Color(0xFFF2F6F3);
  static const Color gold = Color(0xFFB88438);
  static const Color sand = Color(0xFFF4E8D3);
  static const Color line = Color(0xFFDCE5DF);
  static const Color muted = Color(0xFF63736B);
}

Color xiangjiAlertColor(XiangjiAlertState state) => switch (state) {
      XiangjiAlertState.green => const Color(0xFF2F7D5A),
      XiangjiAlertState.yellow => const Color(0xFFB9860B),
      XiangjiAlertState.orange => const Color(0xFFC8641B),
      XiangjiAlertState.red => const Color(0xFFB73737),
      XiangjiAlertState.blue => const Color(0xFF3567A8),
    };

class XiangjiSectionCard extends StatelessWidget {
  const XiangjiSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle = '',
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: XiangjiPalette.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: XiangjiPalette.pine, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: XiangjiPalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: XiangjiPalette.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class XiangjiStateBadge extends StatelessWidget {
  const XiangjiStateBadge({
    super.key,
    required this.label,
    this.color = XiangjiPalette.pine,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class XiangjiAlertBanner extends StatelessWidget {
  const XiangjiAlertBanner({
    super.key,
    required this.state,
    required this.reason,
    this.defaultAction = '',
  });

  final XiangjiAlertState state;
  final String reason;
  final String defaultAction;

  @override
  Widget build(BuildContext context) {
    final color = xiangjiAlertColor(state);
    final behavior = switch (state) {
      XiangjiAlertState.green => '继续，但仍按复核时间回看现实。',
      XiangjiAlertState.yellow => '放慢推进，补齐关键信息。',
      XiangjiAlertState.orange => '缩小投入，优先侦察或做可逆试验。',
      XiangjiAlertState.red => '冻结原计划，不再默认推进。',
      XiangjiAlertState.blue => '出现新机会，先校验再调整路线。',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.label} · $behavior',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(height: 1.35)),
                ],
                if (defaultAction.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '建议行动：$defaultAction',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class XiangjiEmptyState extends StatelessWidget {
  const XiangjiEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.explore_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: XiangjiPalette.pine),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: XiangjiPalette.muted, height: 1.45),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class XiangjiLabeledValue extends StatelessWidget {
  const XiangjiLabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.empty = '尚未形成',
    this.maxLines,
  });

  final String label;
  final String value;
  final String empty;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? empty : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: XiangjiPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            shown,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class XiangjiFormFieldSpec {
  const XiangjiFormFieldSpec({
    required this.keyName,
    required this.label,
    this.hint = '',
    this.initialValue = '',
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String keyName;
  final String label;
  final String hint;
  final String initialValue;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
}

Future<Map<String, String>?> showXiangjiFormDialog(
  BuildContext context, {
  required String title,
  required List<XiangjiFormFieldSpec> fields,
  String submitLabel = '确认',
  String note = '',
}) async {
  final controllers = <String, TextEditingController>{
    for (final field in fields)
      field.keyName: TextEditingController(text: field.initialValue),
  };
  String validationMessage = '';
  final result = await showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.isNotEmpty) ...[
                  Text(
                    note,
                    style: const TextStyle(
                      color: XiangjiPalette.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                for (final field in fields) ...[
                  TextField(
                    controller: controllers[field.keyName],
                    maxLines: field.maxLines,
                    keyboardType: field.keyboardType,
                    decoration: InputDecoration(
                      labelText: '${field.label}${field.required ? ' *' : ''}',
                      hintText: field.hint,
                      alignLabelWithHint: field.maxLines > 1,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (validationMessage.isNotEmpty)
                  Text(
                    validationMessage,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final values = <String, String>{
                for (final field in fields)
                  field.keyName: controllers[field.keyName]!.text.trim(),
              };
              final missing = fields
                  .where((field) => field.required)
                  .where((field) => values[field.keyName]!.isEmpty)
                  .map((field) => field.label)
                  .toList();
              if (missing.isNotEmpty) {
                setDialogState(() {
                  validationMessage = '请填写：${missing.join('、')}';
                });
                return;
              }
              Navigator.of(dialogContext).pop(values);
            },
            child: Text(submitLabel),
          ),
        ],
      ),
    ),
  );
  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}

List<String> xiangjiLines(String value) => value
    .split(RegExp(r'[\n；;]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String xiangjiDateTime(int milliseconds) {
  if (milliseconds <= 0) return '尚未设定';
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

void xiangjiShowMessage(BuildContext context, Object message) {
  final text = message
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
