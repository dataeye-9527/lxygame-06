#!/usr/bin/env python3
"""Independent geometry/supply audit of the authored JSON and bundled mirror."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
catalog = json.loads((root / 'Resources/Data/levels.json').read_text())
embedded = (root / 'Sources/Core/GDLevelsData.inc').read_text().splitlines()[1]
assert json.loads(json.loads(embedded[1:])) == catalog
assert len(catalog['levels']) == 30
waves = []
supplies = []
for level in catalog['levels']:
    topologies = []
    for number, rows in enumerate(level['layouts'], 1):
        cells = {(r, c) for r, row in enumerate(rows)
                 for c, color in enumerate(row) if color != '.'}
        queue = [cell for cell in cells if cell[0] == 0]
        supported = set(queue)
        for r, c in queue:
            x = 1 + 2 * c + r % 2
            for rr in range(max(0, r - 1), r + 2):
                for cc in range(max(0, c - 1), c + 2):
                    candidate = (rr, cc)
                    distance = (x - (1 + 2 * cc + rr % 2)) ** 2 + 3 * (r - rr) ** 2
                    if candidate in cells and candidate not in supported and distance <= 4.001:
                        supported.add(candidate)
                        queue.append(candidate)
        assert supported == cells, (level['id'], number, 'unsupported cells')
        topology = ','.join(f'{r}:{c}' for r, c in sorted(cells))
        topologies.append(topology)
        waves.append(dict(level=level['id'], wave=number, cells=len(cells),
                          depth=len(rows), supported=True, topology=topology))
    if len(topologies) > 1:
        assert topologies[0] != topologies[1], (level['id'], 'wave2 only recoloured')
    if level['objective'] == 'collect':
        supply = sum(''.join(rows).count(str(level['color'])) for rows in level['layouts'])
        assert supply >= level['target'], (level['id'], 'target colour supply')
        supplies.append(dict(level=level['id'], target=level['target'], authoredColorSupply=supply))
unique = len({wave['topology'] for wave in waves if wave['wave'] == 1})
assert unique >= 24
fall_structures = sorted({level['title'] for level in catalog['levels'] if level['objective'] == 'fall'})
assert len(fall_structures) == 3
result = dict(levels=30, chapters=6, levelsPerChapter=5, authoredWaves=len(waves),
              uniqueOpeningTopologies=unique, allSupported=True,
              allWave2TopologiesDiffer=True, fallStructures=fall_structures,
              collectSupplies=supplies, jsonAndBundledMirrorEqual=True, waves=waves)
output = root / 'build/core/campaign-layout-review.json'
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: value for key, value in result.items() if key != 'waves'}, indent=2))
