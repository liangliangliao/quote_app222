"""Check traceability only; this script does not certify product acceptance."""
import json
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
