"""Optional online audit of unique primary references, separate from offline CI."""
import concurrent.futures
import json
import re
import urllib.error
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def check(url):
    try:
        request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (AZ900 reference audit)'})
        with urllib.request.urlopen(request,timeout=25) as response:
            body=response.read(250000).decode('utf-8',errors='replace')
            title=re.search(r'<title>(.*?)</title>',body,re.S|re.I)
            if title and ('404' in title.group(1) or 'page not found' in title.group(1).lower()):
                return (url,'PAGE NOT FOUND')
            return (url,str(response.status))
    except (urllib.error.URLError,TimeoutError) as error:
        return (url,str(error))


def main():
    urls=set()
    for path in list((ROOT/'docs').glob('*.md'))+list((ROOT/'labs').glob('*/README.md')):
        urls.update(re.findall(r'https://(?:learn\.microsoft\.com|azure\.microsoft\.com)/[^\s)\]>]+',path.read_text(encoding='utf-8')))
    for path in (ROOT/'labs').glob('*/questions.json'):
        for question in json.loads(path.read_text(encoding='utf-8')):
            urls.update(question['source_urls'])
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        results=sorted(executor.map(check,urls))
    problems=[(url,status) for url,status in results if status!='200']
    for url,status in problems:
        print(f'{status}: {url}')
    print(f'Checked {len(results)} unique primary references; {len(problems)} need attention')
    if problems:
        raise SystemExit(1)


if __name__=='__main__':
    main()
