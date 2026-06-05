
import 'package:flutter/material.dart';

class QuoteCard extends StatelessWidget {
  final String text;
  final String author;
  final String source;
  const QuoteCard({super.key, required this.text, this.author='', this.source=''});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(left: 12, top: 12, right: 7, bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
Text(
  text,
  style: Theme.of(context).textTheme.titleMedium ??
      Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 20) - 2,
      ),
),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(author.isEmpty ? '' : '—— $author', style: Theme.of(context).textTheme.bodyMedium),
                Text(source, style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          ],
        ),
      ),
    );
  }
}