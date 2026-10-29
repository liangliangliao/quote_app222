"""Check traceability only; this script does not certify product acceptance."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows = json.loads((ROOT / 'docs/will_mirror/acceptance.json').read_text())
assert [r['id'] for r in rows] == [f'T{i}' for i in range(1, 367)]
for row in rows:
    assert row['verification'] and row['remaining'] and row['evidence_limit']
    assert row['verification'] not in ('passed', 'all_passed', 'pending')
    for file in [row['source'], *row['code'], *row['regression_files']]:
        assert (ROOT / file).is_file(), (row['id'], file)
    original = (ROOT / row['source']).read_text().splitlines()[row['line'] - 1]
    assert row['requirement'] == original.strip(), row['id']
scenarios = json.loads((ROOT / 'docs/will_mirror/evaluation/scenarios.json').read_text())
assert len(scenarios) >= 20
assert len({s['id'] for s in scenarios}) == len(scenarios)
assert all(s['initial'] and s['new_evidence'] and s['checks'] for s in scenarios)
print(f'{len(rows)} requirements traced; {len(scenarios)} synthetic evaluation scenarios. Live acceptance is not certified.')

# This recomputes an explicitly manual implementation review, not semantic or
# device acceptance. The original per-requirement verification states remain.
audit = (ROOT / 'docs/will_mirror/AUDIT_2026_10_29.md').read_text()
groups = re.findall(r'^\| (\d+)\. [^\n|]+\| ([\d.]+) \| ([\d.]+) \|', audit, re.M)
assert [int(g[0]) for g in groups] == list(range(1, 21))
assert all(float(value) in (0, 2.5, 5) for g in groups for value in g[1:])
before = sum(float(g[1]) for g in groups)
after = sum(float(g[2]) for g in groups)
print(f'20 manually reviewed P0/P1 groups: {before:g}/100 -> {after:g}/100 implementation coverage estimate; not release acceptance.')
