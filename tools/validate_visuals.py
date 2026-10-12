"""Validate the illustrated curriculum and homepage without writing files."""
import hashlib
import re
import struct
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
from build_docs import LAB_VISUALS as VISUAL_NAMES, render_home

LAB_VISUALS = dict(enumerate(name + '.svg' for name in VISUAL_NAMES))


class PageAssets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []
        self.images = []
        self.ids = []
        self.lab_cards = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and attrs.get('href'):
            self.references.append(('link', attrs['href']))
        if tag == 'img':
            self.images.append(attrs)
            self.references.append(('image', attrs.get('src', '')))
        if 'az900-lab-card' in attrs.get('class', '').split():
            self.lab_cards += 1


def validate_visuals(root, labs):
    errors = []
    documents = []

    def require(condition, message):
        if not condition:
            errors.append(message)

    digests = set()
    for lab in labs:
        filename = LAB_VISUALS[int(lab['id'])]
        relative = '../../docs/assets/diagrams/' + filename
        lesson = root / lab['path'] / 'README.md'
        if not lesson.exists():
            continue
        text = lesson.read_text(encoding='utf-8')
        pattern = r'\[!\[([^\]]+)\]\(' + re.escape(relative) + r'\)\]\(' + re.escape(relative) + r'\)'
        figures = re.findall(pattern, text)
        require(len(figures) == 1, f'Lab {lab["id"]}: expected one clickable topic illustration')
        if figures:
            require(len(figures[0].strip()) >= 25, f'Lab {lab["id"]}: add descriptive visual alt text')
        asset = root / 'docs/assets/diagrams' / filename
        require(asset.is_file(), f'Missing teaching visual: {filename}')
        if asset.is_file():
            digest = hashlib.sha256(asset.read_bytes()).hexdigest()
            require(digest not in digests, f'Duplicate teaching illustration: {filename}')
            digests.add(digest)

    expected = list(LAB_VISUALS.values()) + ['learning-path.svg']
    assets = [root / 'docs/assets/diagrams' / name for name in expected]
    assets += [root / 'docs/assets/illustrations' / f'domain-{name}.svg' for name in ['cloud', 'architecture', 'governance']]
    ns = '{http://www.w3.org/2000/svg}'
    for asset in assets:
        require(asset.is_file(), f'Missing illustrated asset: {asset.name}')
        if not asset.is_file():
            continue
        try:
            svg = ET.parse(asset).getroot()
            require(svg.tag == ns + 'svg', f'Invalid SVG namespace: {asset.name}')
            require(svg.get('role') == 'img', f'Missing SVG image role: {asset.name}')
            title, description = svg.find(ns + 'title'), svg.find(ns + 'desc')
            require(title is not None and bool(''.join(title.itertext()).strip()), f'Missing SVG title: {asset.name}')
            require(description is not None and len(''.join(description.itertext()).strip()) >= 25, f'Missing SVG description: {asset.name}')
            ids = [node.get('id') for node in svg.iter() if node.get('id')]
            require(len(ids) == len(set(ids)), f'Duplicate SVG IDs: {asset.name}')
            labels = svg.get('aria-labelledby', '').split()
            require(len(labels) >= 2 and all(label in ids for label in labels), f'Invalid SVG accessible label references: {asset.name}')
            box = [float(value) for value in svg.get('viewBox', '').split()]
            require(len(box) == 4 and box[2] > 0 and box[3] > 0, f'Invalid SVG viewBox: {asset.name}')
            for node in svg.iter():
                tag = node.tag.rsplit('}', 1)[-1]
                require(tag not in {'script', 'foreignObject', 'animate', 'animateTransform'}, f'Unexpected active SVG content: {asset.name}')
                for key, value in node.attrib.items():
                    require(not key.lower().startswith('on'), f'Unexpected SVG event handler: {asset.name}')
                    if key.rsplit('}', 1)[-1] == 'href':
                        require(value.startswith('#'), f'External SVG asset dependency: {asset.name}')
        except (ET.ParseError, ValueError, IndexError) as error:
            errors.append(f'Invalid SVG {asset.name}: {error}')

    cover = root / 'docs/assets/illustrations/azure-cloud-cover.png'
    require(cover.is_file(), 'Missing original cloud cover artwork')
    if cover.is_file():
        header = cover.read_bytes()[:24]
        require(header.startswith(b'\x89PNG\r\n\x1a\n') and len(header) == 24, 'Cover must be a valid PNG')
        if len(header) == 24:
            width, height = struct.unpack('>II', header[16:24])
            require(width > height > 0, 'Cloud cover must have a landscape composition')

    homepage = root / 'HOME.md'
    require(homepage.is_file(), 'Missing dedicated site homepage')
    if homepage.is_file():
        import json
        blueprint = json.loads((root / 'curriculum/blueprint.json').read_text(encoding='utf-8'))
        try:
            rendered = render_home(labs, blueprint)
            documents.append((homepage, rendered))
            home_parser = PageAssets()
            home_parser.feed(rendered)
            require(home_parser.lab_cards == 22, 'Homepage must link to all 22 lab cards')
            require(len(home_parser.ids) == len(set(home_parser.ids)), 'Duplicate homepage anchor IDs')
            for lab in labs:
                require(('link', lab['path'] + '/') in home_parser.references, f'Homepage card missing lab {lab["id"]}')
        except (SystemExit, KeyError, ValueError) as error:
            errors.append(f'Invalid homepage generation: {error}')

    # Raw HTML is used for accessible homepage figures and GitHub image widths.
    # Validate these references as well as the existing Markdown link checks.
    documents.extend((source, source.read_text(encoding='utf-8')) for source in [root / 'README.md', homepage] if source.is_file())
    for source, text in documents:
        parser = PageAssets()
        parser.feed(text)
        for image in parser.images:
            require('alt' in image, f'HTML image has no alt attribute: {source.name}')
        for kind, reference in parser.references:
            parts = urlsplit(reference)
            if parts.scheme or parts.netloc:
                continue
            if not parts.path:
                continue
            target = (source.parent / unquote(parts.path)).resolve()
            require(target.is_relative_to(root), f'HTML reference leaves repository: {reference}')
            if not target.is_relative_to(root):
                continue
            candidates = [target] if kind == 'image' else [target, target.with_suffix('.md'), target / 'README.md', target / 'index.md']
            require(any(path.exists() for path in candidates), f'Broken HTML {kind} in {source.name}: {reference}')
    return errors
