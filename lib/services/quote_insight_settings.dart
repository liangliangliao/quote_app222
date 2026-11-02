/// Release switches leave the original reader/history available for rollback.
/// Source honesty rules remain active even when optional interactions are off.
class QuoteInsightSettings {
  static const readingEnabled =
      bool.fromEnvironment('QUOTE_READING_INSIGHTS', defaultValue: true);
  static const comparisonEnabled =
      bool.fromEnvironment('QUOTE_COMPARISON_ENABLED', defaultValue: true);
}
