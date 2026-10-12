"""Stage an isolated documentation tree and assessment data for MkDocs."""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / '.site-docs'


def main():
    if STAGE.is_symlink() or STAGE.resolve() != ROOT / '.site-docs':
        raise SystemExit('Refusing an unexpected staging path')
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir()
    for directory in ['docs', 'labs', 'curriculum']:
        shutil.copytree(ROOT / directory, STAGE / directory)
    for name in ['CONTRIBUTING.md', 'SECURITY.md', 'LICENSE']:
        shutil.copy2(ROOT / name, STAGE / name)
    shutil.copy2(ROOT / 'README.md', STAGE / 'index.md')
    catalog = json.loads((ROOT / 'curriculum/catalog.json').read_text(encoding='utf-8'))
    banks = []
    nav = [{'Home':'index.md'}, {'Start here':[{'Prerequisites':'docs/prerequisites.md'}, {'Cost and cleanup':'docs/cost-cleanup.md'}, {'Permissions':'docs/permissions.md'}, {'Study pathways':'docs/study-plan.md'}]}, {'Lab catalog':'docs/catalog.md'}, {'Objective map':'docs/objective-map.md'}]
    for domain, name in [('foundation','Getting started'), ('cloud','Cloud concepts'), ('architecture','Architecture and services'), ('management','Management and governance'), ('capstone','Capstone')]:
        nav.append({name:[{f'{lab["id"]} · {lab["title"]}':lab['path']+'/README.md'} for lab in catalog if lab['domain']==domain]})
    nav += [{'Practice':[{'Assessment guide':'docs/assessments.md'}, {'Interactive quiz':'docs/quiz.md'}]}, {'Glossary':'docs/glossary.md'}, {'Troubleshooting':'docs/troubleshooting.md'}, {'Contributing':'CONTRIBUTING.md'}]
    for lab in catalog:
        if lab['assessment_count']:
            questions = json.loads((ROOT / lab['path'] / 'questions.json').read_text(encoding='utf-8'))
            for q in questions:
                q['review_url'] = lab['path'] + '/' + q['remediation']
            banks.append({'id':lab['id'], 'title':lab['title'], 'questions':questions})
    (STAGE / 'docs/assets/questions.json').write_text(json.dumps(banks,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
    for lab in catalog:
        p = STAGE / lab['path'] / 'README.md'
        text = p.read_text(encoding='utf-8')
        text += f'\n<div class="az900-progress" data-lab-id="{lab["id"]}"></div>\n'
        # Source README links must resolve in the built site when served without .md suffixes.
        p.write_text(text,encoding='utf-8')
    import yaml
    config = {'site_name':'AZ-900 Azure Fundamentals Labs', 'site_description':'22 command-first labs and 600 original questions for Azure Fundamentals.',
      'site_url':'https://jamonygr.github.io/az900-azure-fundamentals-labs/', 'repo_url':'https://github.com/Jamonygr/az900-azure-fundamentals-labs',
      'repo_name':'Jamonygr/az900-azure-fundamentals-labs', 'docs_dir':'.site-docs', 'site_dir':'site',
      'theme':{'name':'material','language':'en','font':False,'features':['navigation.sections','navigation.top','content.code.copy'],
        'palette':[{'scheme':'default','primary':'blue','accent':'cyan','toggle':{'icon':'material/weather-night','name':'Switch to dark mode'}}, {'scheme':'slate','primary':'blue','accent':'cyan','toggle':{'icon':'material/weather-sunny','name':'Switch to light mode'}}]},
      'plugins':['search'], 'markdown_extensions':['admonition','tables','fenced_code','attr_list',{'toc':{'permalink':True}},'pymdownx.highlight','pymdownx.superfences'],
      'extra_javascript':['docs/assets/learning.js'],'extra_css':['docs/assets/learning.css'],'nav':nav,
      'validation':{'nav':{'omitted_files':'ignore'},'links':{'not_found':'warn','anchors':'warn','unrecognized_links':'ignore'}},
      'copyright':'© 2026 Chris Panagiotidis · Independent learning project · MIT License'}
    (ROOT / 'mkdocs.yml').write_text(yaml.safe_dump(config,sort_keys=False,allow_unicode=True),encoding='utf-8')
    print(f'Staged {len(catalog)} labs and {sum(len(bank["questions"]) for bank in banks)} questions')


if __name__ == '__main__':
    main()
