#!/usr/bin/env python3
"""Census of readers of the platform cell's fields outside the cell path (audit pass 17).

The platform cell (Kernel/PlatformCellLayout.lean) owns the creation tariff, the grain-birth
tariff, the completion custodian key and the factory template's owner budget and lifetime.
`profile.template` stays in the semantics digest, so any site that still reads
`template.ownerBudget`/`template.lifetime`, `config.tariff`, `grainBirthTariffValue` or
`config.completionCustodianKey` keeps serving the genesis value after an install, silently.

scripts/platform-field-readers.json lists every such reader per file and pattern, with a
status:
  owed     must read the platform cell before the digest change ships;
  genesis  the genesis seed itself (the record the cell starts from);
  encoding the template's own encoding (issuer and birthSlack stay profile fields);
  other    a different structure's field of the same name: the objective activity's
           `ObjectiveActivity.Config.tariff` is the work tariff (`ObjectiveTariff.Tariff`:
           workOf, domainWork, heap, stack), which the platform cell does not own;
  cell     reads the field through the platform record (`templateAt profile.template record`
           takes only issuer and birthSlack from the profile).
A row's optional `reason` says why a non-owed status holds.

A bare `profile.template` (the whole template handed on) counts as a reader of its owner
budget and lifetime unless the row says otherwise; `templateAt profile.template` is the cell
path and is not counted. Comments are not code and are not counted.

  check-platform-field-readers.py           refuse any reader not in the census, or a count
                                            above its census row (a new silent twin);
  check-platform-field-readers.py --ship    also refuse while any `owed` row remains;
  check-platform-field-readers.py --write   rewrite the counts (keeps statuses and reasons; new rows owed).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CENSUS = ROOT / "scripts" / "platform-field-readers.json"
PATTERN = re.compile(r"template\.(?:ownerBudget|lifetime)|config\.tariff\b|grainBirthTariffValue"
                     r"|config\.completionCustodianKey"
                     r"|(?<!templateAt )(?<!templateAt config\.)profile\.template\b"
                     r"(?!\.(?:issuer|birthSlack|ownerBudget|lifetime)\b)")
EXCLUDED = ("Kernel/PlatformCell", "scripts/", "tests/", "Fixtures/", "Verify/", "Assurance/",
            ".lake/", "docs/")


def code_only(text):
    """Lean source with comments blanked (nested `/- -/` blocks and `--` lines); string
    literals are kept. A field named in prose is not a reader."""
    out, i, depth, n = [], 0, 0, len(text)
    while i < n:
        two = text[i:i + 2]
        if depth:
            if two == "/-":
                depth, i = depth + 1, i + 2
            elif two == "-/":
                depth, i = depth - 1, i + 2
            else:
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
        elif two == "/-":
            depth, i = 1, i + 2
        elif two == "--":
            while i < n and text[i] != "\n":
                i += 1
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def readers():
    files = subprocess.run(["git", "ls-files", "*.lean"], cwd=ROOT, check=True,
                           capture_output=True, text=True).stdout.split()
    found = {}
    for name in files:
        if name.startswith(EXCLUDED):
            continue
        text = code_only((ROOT / name).read_text(encoding="utf-8"))
        for match in PATTERN.finditer(text):
            key = match.group(0)
            found.setdefault(name, {}).setdefault(key, 0)
            found[name][key] += 1
    return found


def main(argv):
    found = readers()
    census = json.loads(CENSUS.read_text()) if CENSUS.exists() else {}
    if "--write" in argv:
        out = {}
        for name, keys in sorted(found.items()):
            for key, count in sorted(keys.items()):
                row = dict(census.get(name, {}).get(key, {"status": "owed"}))
                row["count"] = count
                out.setdefault(name, {})[key] = row
        CENSUS.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n")
        return 0
    errors = []
    for name, keys in sorted(found.items()):
        for key, count in sorted(keys.items()):
            row = census.get(name, {}).get(key)
            if row is None:
                errors.append(f"{name}: reads {key} ({count}x) outside the platform cell path and "
                              "has no census row: read the cell instead")
            elif count > row["count"]:
                errors.append(f"{name}: {key} read {count}x, census allows {row['count']}")
    owed = [(name, key) for name, keys in census.items() for key, row in keys.items()
            if row["status"] == "owed" and found.get(name, {}).get(key)]
    if "--ship" in argv:
        errors += [f"{name}: {key} still owed to the platform cell" for name, key in owed]
    for line in errors:
        print("platform-field-readers:", line)
    print(f"platform-field-readers: {len(owed)} owed rows, {len(errors)} refusals")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
