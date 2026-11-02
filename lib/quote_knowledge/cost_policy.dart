import 'dart:convert';

/// These are conservative estimates, not a provider's metered token usage.
class ClassificationCostPolicy {
  static const batchSize = 8;
  static const maxRetries = 3;
  static const maxQuoteCharacters = 2200;
  static const maxPromptBytes = 10000;
  static const defaultRequests = 3;
  static const estimatedRoundLimit = 48000;
  static int outputLimit(int records) => 256 + records * 220;
  static int estimate(String prompt, int outputLimit) =>
      utf8.encode(prompt).length + 512 + outputLimit;

  static int capOutput(int requested, int configured) =>
      configured < requested ? configured : requested;
}

class ClassificationUsage {
  final int limit,
      used,
      estimatedUsed,
      estimatedLimit,
      local,
      cached,
      ai,
      blocked;
  final bool stopped, running;
  const ClassificationUsage(
      {this.limit = 3,
      this.used = 0,
      this.estimatedUsed = 0,
      this.estimatedLimit = 48000,
      this.local = 0,
      this.cached = 0,
      this.ai = 0,
      this.blocked = 0,
      this.stopped = false,
      this.running = false});
  bool get exhausted => used >= limit || estimatedUsed >= estimatedLimit;
}

class AiReservation {
  final String state, id;
  const AiReservation(this.state, [this.id = '']);
}
