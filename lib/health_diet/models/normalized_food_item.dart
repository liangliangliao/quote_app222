class NormalizedFoodItem {
  const NormalizedFoodItem({
    this.id,
    required this.source,
    required this.sourceId,
    required this.name,
    this.brand,
    this.barcode,
    this.category,
    this.imageUrl,
    this.servingSizeG,
    this.caloriesKcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.saturatedFatG,
    this.allergens = const [],
    this.ingredients = const [],
    this.healthTags = const [],
    this.dataQuality = 'unknown',
    this.raw = const {},
  });

  final int? id;
  final String source;
  final String sourceId;
  final String name;
  final String? brand;
  final String? barcode;
  final String? category;
  final String? imageUrl;
  final double? servingSizeG;
  final double? caloriesKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;
  final double? saturatedFatG;
  final List<String> allergens;
  final List<String> ingredients;
  final List<String> healthTags;
  final String dataQuality;
  final Map<String, dynamic> raw;
}
