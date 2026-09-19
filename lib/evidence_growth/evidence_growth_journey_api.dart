import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';

class EvidenceGrowthJourneyApi {
  static Future<Map<String, Object?>?> dispatch(
      EvidenceGrowthDao dao, String method, Uri uri, GrowthData b) async {
    final p = uri.pathSegments;
    if (p.isEmpty || !RegExp(r'^v2(?:\.[0-7])?$').hasMatch(p[0])) return null;
    final store = dao.journeys;
    if (method == 'POST' && uri.path.endsWith('/problem-space/resolve'))
      return {
        'profile': GrowthProblemProfile.resolve(b['text'] as String? ?? '').data
      };
    if (p.length == 2 && (p[1] == 'journeys' || p[1] == 'explorations')) {
      if (method == 'GET')
        return {'journeys': (await store.list()).map((j) => j.data).toList()};
      if (method == 'POST') {
        final raw = b['text'] as String? ?? '';
        var profile = b['profile'] is Map
            ? GrowthProblemProfile(growthMap(b['profile']))
            : GrowthProblemProfile.resolve(raw);
        if (p[1] == 'explorations')
          profile = GrowthProblemProfile({
            ...profile.data,
            'goal_mode': 'EXPLORE',
            'lifecycle_type': 'EXPLORATORY',
            'intent_clarity': 'UNKNOWN_DISCOVERY'
          });
        return {
          'journey': (await store.create(raw,
                  profile: profile, parentId: b['parent_id'] as String?))
              .data
        };
      }
    }
    if (p.length == 2 && p[1] == 'sync') {
      if (method == 'GET') return {'ids': await store.ids()};
      if (method == 'POST')
        return {
          'digest': await store.importBundle(growthMap(b['bundle']),
              baseDigest: b['base_digest'] as String? ?? '')
        };
    }
    if (p.length == 3 && p[1] == 'sync' && method == 'GET') {
      final bundle = await store.bundle(p[2]);
      return {
        'bundle': bundle,
        'digest': bundle.isEmpty ? '' : EvidenceGrowthDao.bundleDigest(bundle)
      };
    }
    if (p.length >= 2 && p[1] == 'portfolios') {
      if (method == 'GET')
        return {
          'portfolio': await store.portfolio(),
          'arbitration': await store.arbitration()
        };
      if (method == 'POST') {
        if (b['patch'] != null)
          await store.savePortfolio(
              growthInt(b['version']), growthMap(b['patch']));
        return {
          'portfolio': await store.portfolio(),
          'arbitration': await store.arbitration()
        };
      }
    }
    if (p.length >= 2 && p[1] == 'dependencies' && method == 'POST') {
      if (b['operation'] == 'REMOVE') {
        await store.removeDependency(b['from'], b['to'], b['type']);
      } else if (b['from'] != null)
        await store.addDependency(b['from'], b['to'], b['type'],
            evidence: b['evidence'] ?? '');
      return {
        'dependencies': await store.dependencies(b['journey_id'] ?? b['from'])
      };
    }
    if (p.length >= 3 &&
        const ['journeys', 'explorations', 'shared-goals'].contains(p[1])) {
      final j = await store.find(p[2]);
      if (j == null) throw StateError('目标不存在');
      if (method == 'GET')
        return {
          'journey': j.data,
          'history': await store.history(j.id),
          'dependencies': await store.dependencies(j.id)
        };
      if (method == 'POST' && p.length == 4) {
        if (growthInt(b['version']) != j.version)
          throw StateError('VERSION_CONFLICT');
        final aliases = {
          'candidates': 'candidate',
          'participants': 'participant'
        };
        return {
          'journey': (await store.change(j, aliases[p[3]] ?? p[3], b)).data
        };
      }
    }
    throw ArgumentError('未知 v2.7 接口');
  }
}
