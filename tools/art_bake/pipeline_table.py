"""Dev tool: print the ART_PIPELINE sprite table (name | size | anchor) from recipes.json + bots.json."""
import json, os
d = os.path.dirname(os.path.abspath(__file__))
R = json.load(open(d + '/recipes.json')); S = dict(R['sprites'])
bj = json.load(open(d + '/../../game/data/bots.json'))
for b in bj['bots'] + bj.get('rookies', []):
    for suf in ('', '_panic'): S['bot_' + b['name'].lower() + suf] = {'canvas': R['bot_canvas']}
print('| Sprite | Size px (baked 2x) | Anchor px (ground cell centre) |\n|---|---|---|')
for n in sorted(S):
    w, h, ax, ay = S[n]['canvas']; print(f'| `{n}` | {w}x{h} | {ax},{ay} |')
