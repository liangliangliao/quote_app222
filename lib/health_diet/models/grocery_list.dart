class GroceryList {
  const GroceryList({
    this.id,
    required this.userId,
    required this.recipeSourceId,
    required this.recipeTitle,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  final int? id;
  final String userId;
  final String recipeSourceId;
  final String recipeTitle;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final List<GroceryListItem> items;

  factory GroceryList.fromMap(Map<String, Object?> map) {
    return GroceryList(
      id: int.tryParse((map['id'] ?? '').toString()),
      userId: (map['user_id'] ?? 'local_user').toString(),
      recipeSourceId: (map['recipe_source_id'] ?? '').toString(),
      recipeTitle: (map['recipe_title'] ?? '').toString(),
      status: (map['status'] ?? 'active').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  GroceryList copyWith({List<GroceryListItem>? items}) {
    return GroceryList(
      id: id,
      userId: userId,
      recipeSourceId: recipeSourceId,
      recipeTitle: recipeTitle,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items ?? this.items,
    );
  }
}

class GroceryListItem {
  const GroceryListItem({
    this.id,
    this.listId,
    required this.itemName,
    this.amountText,
    this.checked = false,
    this.sortOrder = 0,
  });

  final int? id;
  final int? listId;
  final String itemName;
  final String? amountText;
  final bool checked;
  final int sortOrder;

  factory GroceryListItem.fromMap(Map<String, Object?> map) {
    return GroceryListItem(
      id: int.tryParse((map['id'] ?? '').toString()),
      listId: int.tryParse((map['list_id'] ?? '').toString()),
      itemName: (map['item_name'] ?? '').toString(),
      amountText: map['amount_text']?.toString(),
      checked: (int.tryParse((map['checked'] ?? '0').toString()) ?? 0) == 1,
      sortOrder: int.tryParse((map['sort_order'] ?? '0').toString()) ?? 0,
    );
  }

  Map<String, Object?> toInsertMap(int newListId) => {
        'list_id': newListId,
        'item_name': itemName,
        'amount_text': amountText,
        'checked': checked ? 1 : 0,
        'sort_order': sortOrder,
      };

  GroceryListItem copyWith({bool? checked}) {
    return GroceryListItem(
      id: id,
      listId: listId,
      itemName: itemName,
      amountText: amountText,
      checked: checked ?? this.checked,
      sortOrder: sortOrder,
    );
  }

  String get displayText {
    final amount = amountText?.trim();
    if (amount == null || amount.isEmpty) return itemName;
    return '$itemName $amount';
  }
}
