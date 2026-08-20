import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';

/// 放掉的。列表 + 放掉的原因，单项操作只有「拿回来」。
class KindlingReleasedPage extends StatelessWidget {
  const KindlingReleasedPage({super.key, required this.controller});

  static const Key tipKey = ValueKey<String>('kindling_released_tip');
  static const Key listKey = ValueKey<String>('kindling_released_list');

  final KindlingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: const Text(KCopy.released, style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? _) {
            final List<KItem> items = controller.released;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Text(
                    KCopy.releasedTip,
                    key: tipKey,
                    style: TextStyle(fontSize: 14, color: Color(0xFF9A9A9A)),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            KCopy.emptyReleased,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        )
                      : ListView.separated(
                          key: listKey,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Color(0xFFF0F0F0),
                          ),
                          itemBuilder: (BuildContext context, int i) {
                            final KItem item = items[i];
                            return ListTile(
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF6E6E6E),
                                ),
                              ),
                              subtitle: item.releaseNote == null
                                  ? null
                                  : Text(
                                      item.releaseNote!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFAAAAAA),
                                      ),
                                    ),
                              trailing: TextButton(
                                onPressed: () => controller.restore(item.id),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2B2B2B),
                                ),
                                child: const Text(
                                  KCopy.restore,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
