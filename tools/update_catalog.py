"""Refresh committed learner indexes from authoritative lab metadata."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def render():
    labs = []
    for path in sorted((ROOT / 'labs').glob('*/lab.json')):
        labs.append({**json.loads(path.read_text(encoding='utf-8')), 'path': path.parent.relative_to(ROOT).as_posix()})
    blueprint = json.loads((ROOT / 'curriculum/blueprint.json').read_text(encoding='utf-8'))
    catalog = '# Lab catalog\n\nLive labs require your approved Azure subscription. All labs are offline-validated; author live testing has not been performed.\n\n| Lab | Topic | Route | Minutes | Questions |\n| --- | --- | --- | --- | --- |\n'
    for lab in labs:
        catalog += f'| {lab["id"]} | [{lab["title"]}](../{lab["path"]}/README.md) | {lab["mode"]} | {lab["duration_minutes"]} | {lab["assessment_count"]} |\n'
    coverage = '# Objective map\n\nObjective descriptions are original paraphrases of the [official study guide](' + blueprint['source_url'] + '). Blueprint effective ' + blueprint['blueprint_date'] + '; reviewed ' + blueprint['reviewed_on'] + '. Each ID is local to this repository, not a Microsoft objective number.\n\n'
    for domain in blueprint['domains']:
        coverage += f'## {domain["name"]} ({domain["weight"]})\n\n| ID | Learning objective | Lesson |\n| --- | --- | --- |\n'
        for objective in blueprint['objectives']:
            if objective['domain'] != domain['id']:
                continue
            links = ', '.join(f'[{lab["id"]}](../{lab["path"]}/README.md#objectives)' for lab in labs if objective['id'] in lab['objectives'])
            coverage += f'| {objective["id"]} | {objective["description"]} | {links} |\n'
        coverage += '\n'
    return {'curriculum/catalog.json': json.dumps(labs, indent=2) + '\n', 'docs/catalog.md': catalog, 'docs/objective-map.md': coverage.rstrip() + '\n'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, contents in render().items():
        target = ROOT / name
        if args.check:
            if not target.exists() or target.read_text(encoding='utf-8') != contents:
                raise SystemExit(f'Stale generated index: {name}; run python tools/update_catalog.py')
        else:
            target.write_text(contents, encoding='utf-8')
    print('Learner indexes are current')


if __name__ == '__main__':
    main()
