import '../models/normalized_food_item.dart';
import '../models/normalized_recipe.dart';

abstract class FoodDataSource {
  Future<List<NormalizedFoodItem>> searchFood(String query);
  Future<NormalizedFoodItem?> getFoodDetail(String sourceId);
  Future<NormalizedFoodItem?> getFoodByBarcode(String barcode);
}

abstract class RecipeDataSource {
  Future<List<NormalizedRecipe>> searchRecipes({
    required String query,
    List<String>? healthTags,
    List<String>? dietTags,
    int? maxCalories,
    int? minProtein,
    int? maxSodium,
  });

  Future<NormalizedRecipe?> getRecipeDetail(String sourceId);
}
