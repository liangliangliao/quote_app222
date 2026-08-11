import 'package:flutter/material.dart';

class WillMirrorPalette {
  static const Color ink = Color(0xFF24332E);
  static const Color muted = Color(0xFF64756E);
  static const Color forest = Color(0xFF315D4D);
  static const Color moss = Color(0xFF6E836E);
  static const Color cream = Color(0xFFF6F2E9);
  static const Color sage = Color(0xFFE7EFE9);
  static const Color amber = Color(0xFFE7D7B4);
  static const Color rose = Color(0xFFF3E6E4);
  static const Color line = Color(0xFFDCE4DF);
}

class WillMirrorSectionCard extends StatelessWidget {
  const WillMirrorSectionCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: WillMirrorPalette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

class WillMirrorBadge extends StatelessWidget {
  const WillMirrorBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = WillMirrorPalette.sage,
    this.foreground = WillMirrorPalette.forest,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class WillMirrorEntryTile extends StatelessWidget {
  const WillMirrorEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return WillMirrorSectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WillMirrorPalette.sage,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: WillMirrorPalette.forest, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: WillMirrorPalette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    height: 1.3,
                    fontSize: 12,
                    color: WillMirrorPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              const Icon(Icons.chevron_right, color: WillMirrorPalette.moss),
        ],
      ),
    );
  }
}

class WillMirrorGuardrail extends StatelessWidget {
  const WillMirrorGuardrail({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 13),
      decoration: BoxDecoration(
        color: WillMirrorPalette.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WillMirrorPalette.amber),
      ),
      child: Text(
        compact
            ? '这是可被反证和修订的暂定模型，不是对你本质的证明。'
            : '《意志之镜》帮助你结构化反思，不诊断、不治疗，也不替代专业判断。这里的“意志”来自哲学框架；AI 无法直接测量作为物自身的意志。所有结论都必须接受人生证据、反例与现实实验的修正。',
        style: const TextStyle(
          fontSize: 12,
          height: 1.45,
          color: WillMirrorPalette.muted,
        ),
      ),
    );
  }
}

Future<T?> showWillMirrorTextDialog<T>({
  required BuildContext context,
  required String title,
  required TextEditingController controller,
  required T result,
  String? hint,
  String actionLabel = '保存',
  int maxLines = 4,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isEmpty) return;
            Navigator.pop(context, result);
          },
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}
