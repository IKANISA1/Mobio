class ChatAiAssist {
  const ChatAiAssist({
    required this.source,
    required this.model,
    required this.suggestions,
    required this.completion,
  });

  final String source;
  final String model;
  final List<String> suggestions;
  final String completion;

  factory ChatAiAssist.fromJson(Map<String, dynamic> json) {
    final suggestions = json['suggestions'] is List
        ? (json['suggestions'] as List)
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toList()
        : const <String>[];

    return ChatAiAssist(
      source: (json['source'] as String?) ?? 'fallback',
      model: (json['model'] as String?) ?? 'local-fallback',
      suggestions: suggestions,
      completion: ((json['completion'] as String?) ?? '').trim(),
    );
  }
}
