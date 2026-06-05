class NormalizedRecipe {
  const NormalizedRecipe({
    required this.source,
    required this.sourceId,
    required this.title,
    this.imageUrl,
    this.ingredients = const [],
    this.steps = const [],
    this.healthTags = const [],
    this.dietTags = const [],
    this.cautions = const [],
    this.caloriesKcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.sodiumMg,
    this.readyMinutes,
    this.servings,
    this.dataQuality = 'unknown',
    this.raw = const {},
  });

  final String source;
  final String sourceId;
  final String title;
  final String? imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> healthTags;
  final List<String> dietTags;
  final List<String> cautions;
  final double? caloriesKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? sodiumMg;
  final int? readyMinutes;
  final int? servings;
  final String dataQuality;
  final Map<String, dynamic> raw;
}
