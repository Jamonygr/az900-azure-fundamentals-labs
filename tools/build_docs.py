"""Stage an isolated documentation tree and assessment data for MkDocs."""
import json
from html import escape
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / '.site-docs'

DOMAIN_COPY = {
    'cloud': ('Build your cloud vocabulary', 'Understand responsibility, cloud models, pricing, and the service layers behind modern applications.', 'domain-cloud.svg'),
    'architecture': ('Meet the services', 'Connect the dots between Azure regions, compute, networks, storage, identity, and security.', 'domain-architecture.svg'),
    'management': ('Operate with confidence', 'Explore costs, governance, management tools, infrastructure as code, and monitoring.', 'domain-governance.svg'),
}
GROUP_COPY = {
    'foundation': ('00 · Get ready', 'Prepare your tools and learn the safety conventions before your first exercise.'),
    'cloud': ('01–05 · Cloud concepts', 'Start with the ideas that explain why cloud services work the way they do.'),
    'architecture': ('06–13 · Architecture and services', 'Turn abstract concepts into a clear picture of the Azure platform.'),
    'management': ('14–20 · Management and governance', 'Learn how to organize, protect, observe, and control Azure environments.'),
    'capstone': ('21 · Bring it together', 'Connect your skills in a complete deploy, validate, explain, and cleanup scenario.'),
}
MODE_COPY = {'concept': 'Concept exercise', 'read-only': 'Read-only inspection', 'live': 'Hands-on Azure'}
LAB_VISUALS = [
    'safe-workflow', 'shared-responsibility', 'cloud-models', 'cloud-pricing',
    'cloud-benefits', 'service-models', 'azure-hierarchy', 'compute-choices',
    'virtual-networking', 'storage-decisions', 'migration-paths', 'identity-directory',
    'identity-access', 'security-layers', 'cost-controls', 'governance-controls',
    'purview-data', 'hybrid-management', 'iac-deployment', 'health-triage',
    'monitoring-signals', 'capstone-architecture',
]


def render_home(catalog, blueprint):
    """Expand the three documented HOME.md markers from curriculum source data.

    HOME.md remains the editable presentation source. Counts, domain weights,
    lesson links, durations, and modes come from the validated curriculum files.
    Only the staged index is generated; HOME.md itself is never rewritten.
    """
    stats = (
        '<dl class="az900-stats" aria-label="Curriculum at a glance">'
        f'<div><dt>Guided labs</dt><dd>{len(catalog)}</dd></div>'
        f'<div><dt>Original questions</dt><dd>{sum(lab["assessment_count"] for lab in catalog)}</dd></div>'
        f'<div><dt>Mapped objectives</dt><dd>{len(blueprint["objectives"])}</dd></div>'
        '</dl>'
    )
    domain_cards = []
    for domain in blueprint['domains']:
        key = domain['id']
        labs = [lab for lab in catalog if lab['domain'] == key]
        heading, description, filename = DOMAIN_COPY[key]
        image = 'docs/assets/illustrations/' + filename
        first = labs[0]['path'] + '/'
        domain_cards.append(
            f'<article class="az900-domain-card az900-domain-{escape(key)}">'
            f'<figure><a href="{image}" aria-label="Open {escape(domain["name"])} illustration at full size">'
            f'<img src="{image}" alt="{escape(description)}" width="720" height="480" loading="lazy"></a>'
            f'<figcaption>{escape(domain["name"])} · <a href="{image}">Full-size visual</a></figcaption></figure>'
            f'<p class="az900-eyebrow">{escape(domain["weight"])} of the exam</p>'
            f'<h3><a href="{first}">{escape(heading)} <span aria-hidden="true">↗</span></a></h3>'
            f'<p>{escape(description)}</p>'
            f'<p class="az900-card-meta">{len(labs)} labs <span aria-hidden="true">·</span> '
            f'{sum(lab["assessment_count"] for lab in labs)} questions</p></article>'
        )
    groups = []
    for domain, (heading, description) in GROUP_COPY.items():
        cards = []
        for lab in (item for item in catalog if item['domain'] == domain):
            assessment = (f'{lab["assessment_count"]} questions' if lab['assessment_count'] else 'Completion checklist')
            visual = f'docs/assets/diagrams/{LAB_VISUALS[int(lab["id"])]}.svg'
            cards.append(
                f'<article class="az900-lab-card az900-domain-{escape(domain)}">'
                f'<figure class="az900-lab-visual"><a href="{visual}" aria-label="Open lab {escape(lab["id"])} visual at full size">'
                f'<img src="{visual}" alt="Visual guide to {escape(lab["title"].lower())}" width="1200" height="650" loading="lazy"></a>'
                f'<figcaption>Lab {escape(lab["id"])} visual guide · <a href="{visual}">Full size</a></figcaption></figure>'
                f'<div class="az900-lab-top"><span class="az900-lab-number">{escape(lab["id"])}</span>'
                f'<span class="az900-mode az900-mode-{escape(lab["mode"])}">{escape(MODE_COPY[lab["mode"]])}</span></div>'
                f'<h3><a href="{escape(lab["path"])}/">{escape(lab["title"])}</a></h3>'
                f'<p class="az900-card-meta"><span>{lab["duration_minutes"]} min</span>'
                f'<span>{assessment}</span></p>'
                f'<a class="az900-card-link" href="{escape(lab["path"])}/">Open lab <span aria-hidden="true">→</span>'
                f'<span class="az900-sr-only"> {escape(lab["id"])}</span></a></article>'
            )
        groups.append(
            f'<section class="az900-lab-group" aria-labelledby="group-{domain}">'
            f'<div class="az900-group-heading"><h3 id="group-{domain}">{escape(heading)}</h3>'
            f'<p>{escape(description)}</p></div><div class="az900-lab-grid">{"".join(cards)}</div></section>'
        )
    text = (ROOT / 'HOME.md').read_text(encoding='utf-8')
    for marker, content in {
        '<!-- AZ900_STATS -->': stats,
        '<!-- AZ900_DOMAINS -->': '<div class="az900-domain-grid">' + ''.join(domain_cards) + '</div>',
        '<!-- AZ900_LAB_CARDS -->': ''.join(groups),
    }.items():
        if text.count(marker) != 1:
            raise SystemExit(f'HOME.md must contain exactly one {marker}')
        text = text.replace(marker, content)
    # Keep presentation markup as raw HTML and the native skip target as one
    # Markdown H1. Check this contract before staging the homepage for MkDocs.
    import markdown
    rendered = markdown.markdown(text, extensions=['attr_list', 'toc'])
    if re.search(r'<(?:pre|code)(?:\s|>)', rendered) or re.search(r'&lt;/?(?:div|section|p|a|figure)\b', rendered):
        raise SystemExit('HOME.md renders presentation HTML as code; keep the illustrated layout as raw HTML')
    if len(re.findall(r'<h1(?:\s|>)', rendered)) != 1 or not re.search(r'<h1[^>]*\bid="home-title"', rendered):
        raise SystemExit('HOME.md must render one Markdown H1 with the home-title anchor for the native skip link')
    return text


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
    catalog = json.loads((ROOT / 'curriculum/catalog.json').read_text(encoding='utf-8'))
    blueprint = json.loads((ROOT / 'curriculum/blueprint.json').read_text(encoding='utf-8'))
    (STAGE / 'index.md').write_text(render_home(catalog, blueprint), encoding='utf-8')
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
