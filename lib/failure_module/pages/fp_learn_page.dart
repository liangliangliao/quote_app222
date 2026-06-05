import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_episode_page.dart';

class FpLearnPage extends StatelessWidget {
  const FpLearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FpEpisode>>(
      future: FpDao().listEpisodes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final eps = snap.data ?? const [];
        if (eps.isEmpty) {
          return const Center(child: Text('暂无内容'));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: eps.length,
          itemBuilder: (context, i) {
            final e = eps[i];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              child: ListTile(
                title: Text(e.titleZh, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${e.titleEn} · ${e.totalBigSections}大段 · ${e.totalSegments}小段'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FpEpisodePage(episode: e)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
