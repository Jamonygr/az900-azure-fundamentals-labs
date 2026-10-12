"""Offline content, coverage, reference, and secret checks; never contacts Azure."""
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

from jsonschema import Draft202012Validator, FormatChecker
from validate_visuals import validate_visuals

ROOT = Path(__file__).resolve().parents[1]
HEADINGS = ['Objectives', 'Prerequisites', 'Scenario', 'Concept primer', 'Guided exercise', 'Expected results', 'Knowledge check', 'Troubleshooting', 'Cleanup', 'References']
EXCLUDED = {'.git', '.site-docs', 'site', '.venv', 'evidence', '__pycache__'}


def anchors(text):
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    return {re.sub(r'[^\w\- ]', '', m.strip().lower()).replace(' ', '-') for m in re.findall(r'^#+\s+(.+?)\s*$', text, re.M)}


def validate():
    errors = []
    def require(ok, message):
        if not ok:
            errors.append(message)
    def read(path):
        return json.loads(path.read_text(encoding='utf-8'))
    def schema(name, data, location):
        validator = Draft202012Validator(read(ROOT / 'curriculum' / name), format_checker=FormatChecker())
        for error in validator.iter_errors(data):
            errors.append(f'{location}: {error.message}')
    blueprint = read(ROOT / 'curriculum/blueprint.json')
    schema('blueprint-schema.json', blueprint, 'blueprint')
    objectives = {item['id']: item for item in blueprint['objectives']}
    require(len(objectives) == 57, 'Expected 57 distinct objectives')
    labs = read(ROOT / 'curriculum/catalog.json')
    require([item['id'] for item in labs] == [f'{i:02}' for i in range(22)], 'Lab IDs must be 00–21')
    mapped, assessed, stems, ids, total = set(), set(), set(), set(), 0
    for lab in labs:
        folder = ROOT / lab['path']
        meta = read(folder / 'lab.json')
        schema('lab-schema.json', meta, lab['path'])
        require({k:v for k,v in lab.items() if k != 'path'} == meta, f'Catalog drift: {lab["id"]}')
        mapped.update(meta['objectives'])
        require(set(meta['objectives']) <= objectives.keys(), f'Unknown objective: {lab["id"]}')
        for oid in meta['objectives']:
            require(objectives.get(oid, {}).get('domain') == meta['domain'], f'Domain mismatch: {lab["id"]}/{oid}')
        lesson = folder / 'README.md'
        if not lesson.exists():
            errors.append(f'Missing lesson: {lab["id"]}')
            continue
        text = lesson.read_text(encoding='utf-8')
        for heading in HEADINGS:
            require(f'## {heading}\n' in text, f'Missing heading {heading}: {lab["id"]}')
        require(len(text.split()) >= 400, f'Lesson too thin: {lab["id"]}')
        if meta['mode'] == 'live':
            for script in ['Preflight.ps1', 'Setup.ps1', 'Validate.ps1', 'Cleanup.ps1']:
                require((folder / script).exists(), f'Missing {script}: {lab["id"]}')
        bank = folder / 'questions.json'
        if not meta['assessment_count']:
            require(not bank.exists(), f'Unexpected assessment: {lab["id"]}')
            continue
        if not bank.exists():
            errors.append(f'Missing questions: {lab["id"]}')
            continue
        questions = read(bank)
        schema('question-schema.json', questions, str(bank.relative_to(ROOT)))
        require(len(questions) == 30, f'Expected 30 questions: {lab["id"]}')
        letters = {k:0 for k in 'ABCD'}
        for question in questions:
            qid = question['id']
            require(qid not in ids and qid.startswith(lab['id']+'-'), f'Duplicate/incorrect question ID: {qid}')
            ids.add(qid)
            stem = re.sub(r'\W+', '', question['stem'].casefold())
            require(stem not in stems, f'Duplicate question stem: {qid}')
            stems.add(stem)
            require(len(set(question['choices'].values())) == 4, f'Duplicate choices: {qid}')
            require(question['objective_id'] in meta['objectives'], f'Question objective mismatch: {qid}')
            assessed.add(question['objective_id'])
            letters[question['answer']] += 1
            target, _, anchor = question['remediation'].partition('#')
            remediation = (folder / target).resolve()
            require(remediation.is_relative_to(ROOT) and remediation.exists(), f'Invalid remediation file: {qid}')
            if remediation.exists():
                require(anchor in anchors(remediation.read_text(encoding='utf-8')), f'Invalid remediation anchor: {qid}')
            for source in question['source_urls']:
                require(urlsplit(source).hostname in {'learn.microsoft.com', 'azure.microsoft.com'}, f'Non-primary source: {qid}')
        require(all(letters.values()), f'All answer letters must occur: {lab["id"]}')
        total += len(questions)
    require(mapped == objectives.keys(), f'Unmapped/unknown objectives: {sorted(objectives.keys()-mapped)}')
    require(assessed == objectives.keys(), f'Unassessed objectives: {sorted(objectives.keys()-assessed)}')
    require(total == 600, f'Expected 600 questions, got {total}')
    errors.extend(validate_visuals(ROOT, labs))
    for path in ROOT.rglob('*'):
        if not path.is_file() or any(part in EXCLUDED for part in path.relative_to(ROOT).parts):
            continue
        if path.name == 'learner.config.json' or path.suffix not in {'.md', '.json', '.ps1', '.psm1', '.py', '.yml', '.bicep', '.js', '.css', '.txt'}:
            continue
        text = path.read_text(encoding='utf-8')
        require(not re.search(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)', text), f'Possible credential: {path.relative_to(ROOT)}')
        if path.suffix == '.md':
            for label, destination in re.findall(r'\[([^\]]*)\]\(([^)]+)\)', re.sub(r'```.*?```', '', text, flags=re.S)):
                if urlsplit(destination).scheme or destination.startswith('#'):
                    continue
                dest, _, anchor = unquote(destination).partition('#')
                target = (path.parent / dest).resolve()
                require(target.is_relative_to(ROOT) and target.exists(), f'Broken local link in {path.relative_to(ROOT)}: {destination}')
                if target.exists() and target.suffix == '.md' and anchor:
                    require(anchor in anchors(target.read_text(encoding='utf-8')), f'Broken anchor in {path.relative_to(ROOT)}: {destination}')
    subprocess.run([sys.executable, str(ROOT / 'tools/update_catalog.py'), '--check'], check=True)
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'PASS: 22 labs, {total} questions, {len(objectives)} objectives, 22 teaching visuals, homepage cards, schemas, links, and credential patterns')


if __name__ == '__main__':
    validate()
