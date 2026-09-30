"""Read the supplied workbook without changing it; export the runtime catalog."""
import argparse
import json
from pathlib import Path
import openpyxl

IDS = ['swordsman', 'guard', 'paladin', 'heavy_infantry', 'archer',
       'sniper', 'ice_archer', 'sniper_plus', 'ice_archer_plus', 'cavalry',
       'ranger', 'lancer', 'scout', 'cataphract', 'assassin', 'hermit',
       'berserker', 'hermit_dodge', 'hermit_blink', 'berserker_plus']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('workbook')
    parser.add_argument('--output', default='resources/rts/units.json')
    args = parser.parse_args()
    sheet = openpyxl.load_workbook(args.workbook, data_only=True).worksheets[0]
    rows = [(i, r) for i, r in enumerate(sheet.values, 1) if i > 1 and r[0]]
    if len(rows) != len(IDS):
        raise ValueError('Expected the 20 unit rows from 数值_初版.xlsx')
    units = []
    for unit_id, (row, r) in zip(IDS, rows):
        tech, tier = map(int, r[2].split('+'))
        units.append(dict(id=unit_id, name=r[0], cost=r[1], tech=tech, tier=tier,
                          hp=r[3], range=1 if r[4] == '近战' else r[4],
                          ranged=r[4] != '近战', attack=r[5], crit_multiplier=r[6],
                          crit_chance=r[7], attack_speed=r[8], move_speed=r[9],
                          dodge=r[10], ranged_damage_modifier=r[11], capacity=r[12],
                          skill=r[13] or '', source_row=row))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'source': '数值_初版.xlsx / Sheet1', 'units': units}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Imported {len(units)} units to {output}')

if __name__ == '__main__':
    main()
