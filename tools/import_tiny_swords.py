"""Copy the selected, unmodified Tiny Swords PNGs into the game project."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    destination = root / 'assets/tiny_swords'
    paths = []
    for group in ('Terrain', 'Deco'):
        paths.extend((args.source / group).rglob('*.png'))
    for color in ('Blue', 'Red', 'Yellow'):
        for troop in ('Warrior', 'Archer', 'Pawn'):
            paths.append(args.source / f'Factions/Knights/Troops/{troop}/{color}/{troop}_{color}.png')
        paths.append(args.source / f'Factions/Goblins/Troops/Torch/{color}/Torch_{color}.png')
    for building in ('Castle', 'House', 'Tower'):
        for state in ('Blue', 'Red', 'Yellow', 'Construction', 'Destroyed'):
            paths.append(args.source / f'Factions/Knights/Buildings/{building}/{building}_{state}.png')
    for rel in ('Factions/Knights/Troops/Dead/Dead.png',
                'Factions/Knights/Troops/Archer/Arrow/Arrow.png',
                'Factions/Goblins/Buildings/Wood_House/Goblin_House.png',
                'Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png',
                'Resources/Trees/Tree.png', 'Resources/Resources/G_Idle.png',
                'Resources/Resources/G_Spawn.png', 'Effects/Explosion/Explosions.png'):
        paths.append(args.source / rel)
    manifest = []
    for src in sorted(set(paths)):
        relative = src.relative_to(args.source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        manifest.append({'path': relative.as_posix(), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (destination / 'manifest.json').write_text(json.dumps({'pack': 'Tiny Swords (Update 010)',
        'source': 'User supplied local asset pack', 'unmodified_pngs': manifest}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Copied {len(manifest)} original PNGs; .import files and source artwork were not copied.')

if __name__ == '__main__':
    main()
