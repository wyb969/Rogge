"""Validate catalog completeness and printf signatures without launching the game."""
import csv, json, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
rows=list(csv.DictReader((root/'locale/messages.csv').open()))
keys={r['keys'] for r in rows}
assert len(keys)==len(rows),'Duplicate translation keys'
signature=re.compile(r'%(?:%|\d*(?:\.\d+)?[sdf])')
for row in rows:
 for lang in ['en','zh_CN']:
  assert row[lang],(row['keys'],'empty',lang)
  assert signature.findall(row['keys'])==signature.findall(row[lang]),(row['keys'],lang,'format placeholders differ')
  if lang=='en':assert not re.search('[\u4e00-\u9fff]',row[lang]),('Untranslated English',row['keys'])
missing=[]
# Skip comments and the deliberate font glyph cache, not localized display text.
tokens=re.compile(r'#[^\n]*|"""[\s\S]*?"""|"(?:\\.|[^"\\])*"')
for p in list((root/'script').glob('*.gd'))+list((root/'scenes').glob('*.gd'))+list((root/'scenes').glob('*.tscn')):
 if p.name=='ui_fonts.gd':continue
 for m in tokens.finditer(p.read_text()):
  if m[0].startswith('#'):continue
  s=m[0].strip('"').replace('\\n','\n')
  if s=='简体中文':continue # Native language picker endonym; intentionally never translated.
  if re.search('[\u4e00-\u9fff]',s) and s not in keys:missing.append((str(p.relative_to(root)),s))
assert not missing,missing
print(json.dumps({'passed':True,'catalog_rows':len(rows),'locales':['en','zh_CN'],'checks':['unique keys','nonempty translations','printf placeholder parity','English has no Chinese','source Chinese display-string coverage']},indent=2))
