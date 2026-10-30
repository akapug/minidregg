#!/usr/bin/env python3
"""Adapt Wekan's tagged Sandstorm definition to the minidregg signing identity."""
import sys
from pathlib import Path

source, destination, app_id = sys.argv[1:4]
text = Path(source).read_text()

old_id = "m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h"
assert len(app_id) == 52 and app_id.isalnum() and app_id.islower()
assert text.count(f'id = "{old_id}",') == 1
text = text.replace(f'id = "{old_id}",', f'id = "{app_id}",')

old_author = '''      author = (
        contactEmail = "x@xet7.org",
        pgpSignature = embed "meta/wekanteam-pgp-sig",
      ),

      pgpKeyring = embed "meta/keyring",
'''
assert text.count(old_author) == 1
# The upstream signature statement covers the upstream app ID, not this key's ID.
text = text.replace(old_author, '      author = (upstreamAuthor = "Wekan Team"),\n')

old_map = '''    searchPath = [
      (sourcePath = ".meteor-spk/deps"),
      (sourcePath = ".meteor-spk/bundle"),
    ]
'''
assert text.count(old_map) == 1
text = text.replace(old_map, '''    searchPath = [
      (sourcePath = "../upstream-spk"),
    ]
''')
assert 'apiPath = "/",' in text
assert '(key = "WITH_API", value = "true")' in text
assert 'pgpSignature' not in text and 'pgpKeyring' not in text
Path(destination).write_text(text)
