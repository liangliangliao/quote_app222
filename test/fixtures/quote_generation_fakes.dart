import 'package:quote_app/data/kv_dao.dart';
import 'package:quote_app/data/quote_generation_history.dart';

class MemoryQuoteHistory extends QuoteGenerationHistory {
  MemoryQuoteHistory([List<QuoteHistoryEntry> initial = const []])
      : entries = [...initial];
  final List<QuoteHistoryEntry> entries;

  @override
  Future<List<QuoteHistoryEntry>> load() async => [...entries];

  @override
  Future<bool> rememberIfUnchanged(
    QuoteHistoryEntry entry, {
    required String taskUid,
    required List<QuoteHistoryEntry> checkedHistory,
  }) async {
    if (QuoteHistoryEntry.revision(entries) !=
            QuoteHistoryEntry.revision(checkedHistory) ||
        entries.any(entry.sameTextAs)) return false;
    entries.insert(0, entry);
    return true;
  }
}

class MemoryQuoteKeyValue extends KeyValueDao {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
