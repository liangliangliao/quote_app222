import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grocery_list.dart';
import '../repositories/grocery_list_repository.dart';
import '../widgets/health_diet_data_source_banner.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key, this.initialListId});

  final int? initialListId;

  @override
  State<GroceryListPage> createState() => _GroceryListPageState();
}

class _GroceryListPageState extends State<GroceryListPage> {
  final _repo = GroceryListRepository();
  bool _loading = true;
  GroceryList? _activeList;
  List<GroceryList> _recentLists = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    GroceryList? active;
    if (widget.initialListId != null) {
      active = await _repo.getList(widget.initialListId!);
    }
    final recent = await _repo.recentLists();
    active ??= recent.isNotEmpty ? recent.first : null;
    if (!mounted) return;
    setState(() {
      _activeList = active;
      _recentLists = recent;
      _loading = false;
    });
  }

  Future<void> _toggleItem(GroceryListItem item, bool value) async {
    if (item.id == null) return;
    await _repo.updateItemChecked(item.id!, value);
    await _load();
  }

  Future<void> _deleteList(GroceryList list) async {
    if (list.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除购物清单？'),
        content: Text('将删除“${list.recipeTitle}”对应的购物清单。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteList(list.id!);
    await _load();
  }

  Future<void> _copyList() async {
    final list = _activeList;
    if (list == null) return;
    final text = StringBuffer('购物清单：${list.recipeTitle}\n');
    for (final item in list.items) {
      text.writeln('- ${item.displayText}');
    }
    await Clipboard.setData(ClipboardData(text: text.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('购物清单已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('购物清单'),
        actions: [
          IconButton(
            tooltip: '复制清单',
            onPressed: _activeList == null ? null : _copyList,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['已保存菜谱', '本地购物清单', '用户勾选状态'],
                    updatedAt: DateTime.now(),
                    note: '购物清单来自菜谱或手动添加，适合作为执行辅助，不代表营养处方。',
                  ),
                  if (_activeList == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('还没有购物清单。可以先进入“健康菜谱制作”，在菜谱详情页生成购物清单。'),
                      ),
                    )
                  else ...[
                    _activeListCard(_activeList!),
                    const SizedBox(height: 14),
                    _sectionTitle('食材'),
                    ..._activeList!.items.map(_itemTile),
                  ],
                  if (_recentLists.length > 1) ...[
                    const SizedBox(height: 18),
                    _sectionTitle('最近购物清单'),
                    ..._recentLists.where((e) => e.id != _activeList?.id).map(_recentListTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _activeListCard(GroceryList list) {
    final done = list.items.where((e) => e.checked).length;
    final total = list.items.length;
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(list.recipeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => _deleteList(list), icon: const Icon(Icons.delete_outline)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          Text('已勾选 $done / $total 项。勾选状态保存在本地。', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _itemTile(GroceryListItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: CheckboxListTile(
        value: item.checked,
        onChanged: (value) => _toggleItem(item, value ?? false),
        title: Text(item.itemName),
        subtitle: item.amountText?.isNotEmpty == true ? Text(item.amountText!) : null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _recentListTile(GroceryList list) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(list.recipeTitle),
        subtitle: Text('${list.items.length} 项食材'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _activeList = list),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}
