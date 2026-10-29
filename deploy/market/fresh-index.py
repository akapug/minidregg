#!/usr/bin/env python3
"""fresh-index.py: the operator-pinned index for the packages we build ourselves.

Runs where the built packages are (dregg-forge, /var/lib/spk-fresh/apps/<app>/out/<app>.spk with the
`spk verify --details` text next to it as verify.txt). For each package it writes one entry in the
market's own shape (docs/APP-MARKET-2026-10-27.md section 1; `mini apps index-check --local` parses it):

  appId, packageId, name, version, versionNumber, author, upstreamAuthor, shortDescription, categories,
  webLink, codeLink, packageBuiltAt, upstreamVersion, isOpenSource,
  sha256      the WHOLE raw SHA-256 of the .spk, computed here from the bytes (never read from a sidecar),
  packageUrl  BASE_URL + packageId + ".spk",
  class       S, M or L: the sizing from the app's recipe qualify.tsv, else --default-class.

The packageId is checked against the bytes (the first 16 bytes of the SPK's SHA-256) and against
verify.txt; the install path verifies it again like any package, so this file is a pin, not a trust root.

  fresh-index.py --apps DIR --recipes apps/packages --base-url https://HOST/PATH/ --out OUT_DIR

without --base-url the entries carry no packageUrl: the operator adopts each file (mini-market-fetch
adopt PACKAGE-ID SHA256 FILE). Writes OUT_DIR/local.json (the operator copies it to /var/lib/mini-market/local.json), OUT_DIR/adopt.tsv (adopt mode) or OUT_DIR/packages/<packageId>.spk (URL mode: hard links, or
copies across filesystems; the web server's document root), and OUT_DIR/SHA256SUMS. Where two builds of
one appId exist (a rebuild directory), the newest wins; two different appIds never merge.
"""
import argparse, datetime, hashlib, json, os, re, subprocess, sys

LOCAL_FIELDS = ("appId", "packageId", "name", "version", "versionNumber", "author", "upstreamAuthor",
                "shortDescription", "categories", "webLink", "codeLink", "packageBuiltAt",
                "upstreamVersion", "isOpenSource", "sha256", "packageUrl", "class")


def text_field(verify, *path):
    """The first `"defaultText": "..."` string under the named key, or ''."""
    key = path[-1]
    m = re.search(r'"%s":\s*\{\s*"defaultText":\s*"((?:[^"\\]|\\.)*)"' % re.escape(key), verify)
    return json.loads('"%s"' % m.group(1)).strip() if m else ""


def plain(verify, key):
    m = re.search(r'"%s":\s*"((?:[^"\\]|\\.)*)"' % re.escape(key), verify)
    return json.loads('"%s"' % m.group(1)) if m else ""


def parse_verify(text):
    app = re.search(r'"appId":\s*"([a-z0-9]{52})"', text)
    pkg = re.search(r'"packageId":\s*"([0-9a-f]{32})"', text)
    ver = re.search(r'"version":\s*(\d+)', text)
    cats = re.search(r'"categories":\s*\[([^\]]*)\]', text)
    title = re.search(r'"title":\s*\{\s*"defaultText":\s*"((?:[^"\\]|\\.)*)"', text)
    if not (app and pkg and ver and title):
        raise ValueError("verify text lacks appId, packageId, version or title")
    return {
        "appId": app.group(1), "packageId": pkg.group(1), "versionNumber": int(ver.group(1)),
        "name": json.loads('"%s"' % title.group(1)).strip(),
        "version": text_field(text, "marketingVersion"),
        "shortDescription": text_field(text, "shortDescription"),
        "categories": [c.strip().strip('"') for c in cats.group(1).split(",") if c.strip()] if cats else [],
        "webLink": plain(text, "website"), "codeLink": plain(text, "codeUrl"),
        "upstreamAuthor": plain(text, "upstreamAuthor"),
        "isOpenSource": '"openSource"' in text,
    }


def recipe_class(recipes, app_dir, default):
    path = os.path.join(recipes, app_dir, "qualify.tsv")
    try:
        for line in open(path):
            fields = line.split()
            if len(fields) >= 4 and fields[3] in ("S", "M", "L"):
                return fields[3]
    except OSError:
        pass
    return default


def built_at(out_dir, spk):
    for name in ("build-date-utc", "build-date-utc.txt", "build-date.txt"):
        try:
            value = open(os.path.join(out_dir, name)).read().strip()
            if re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
                return value
        except OSError:
            pass
    stamp = datetime.datetime.fromtimestamp(os.path.getmtime(spk), datetime.timezone.utc)
    return stamp.strftime("%Y-%m-%dT%H:%M:%SZ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apps", required=True)
    ap.add_argument("--recipes", required=True)
    ap.add_argument("--base-url", default="", help="https URL ending in /; empty makes adopt-mode entries (no packageUrl)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--default-class", default="M")
    ap.add_argument("--spk-tool", default="", help="the Sandstorm spk binary; run as `spk verify --details FILE` for a package with no verify.txt")
    ap.add_argument("--author", default="Mini")
    ap.add_argument("--adopt-root", default="", help="where --apps is visible on the box that adopts (a bind mount); adopt.tsv names files under it")
    args = ap.parse_args()
    if args.base_url and not (args.base_url.startswith("https://") and args.base_url.endswith("/")):
        sys.exit("fresh-index: --base-url must be https:// and end with /")
    best = {}
    for app_dir in sorted(os.listdir(args.apps)):
        out = os.path.join(args.apps, app_dir, "out")
        verify_path = os.path.join(out, "verify.txt")
        spks = [f for f in (os.listdir(out) if os.path.isdir(out) else []) if f.endswith(".spk")]
        if not spks:
            continue
        spk = os.path.join(out, spks[0])
        if os.path.exists(verify_path):
            verify_text = open(verify_path).read()
        elif args.spk_tool:
            run = subprocess.run([args.spk_tool, "verify", "--details", spk], capture_output=True, text=True, timeout=300)
            if run.returncode != 0:
                sys.exit("fresh-index: spk verify refused %s: %s" % (spk, run.stderr.strip()[:200]))
            verify_text = run.stdout
        else:
            continue
        digest = hashlib.sha256(open(spk, "rb").read()).hexdigest()
        entry = parse_verify(verify_text)
        if digest[:32] != entry["packageId"]:
            sys.exit("fresh-index: %s: the bytes hash to package %s, verify.txt says %s" % (spk, digest[:32], entry["packageId"]))
        entry.update({
            "author": {"name": args.author},
            "packageBuiltAt": built_at(out, spk), "upstreamVersion": entry["version"],
            "sha256": digest, **({"packageUrl": args.base_url + entry["packageId"] + ".spk"} if args.base_url else {}),
            "class": recipe_class(args.recipes, app_dir.split("-r")[0] if app_dir.endswith(("-r2", "-r3")) else app_dir, args.default_class),
            "_spk": spk,
        })
        old = best.get(entry["appId"])
        if old is None or entry["packageBuiltAt"] > old["packageBuiltAt"]:
            best[entry["appId"]] = entry
    if not best:
        sys.exit("fresh-index: no built package (with a verify.txt or --spk-tool) under %s" % args.apps)
    os.makedirs(os.path.join(args.out, "packages"), exist_ok=True)
    apps, sums, adopt = [], [], []
    for entry in sorted(best.values(), key=lambda e: e["name"].lower()):
        spk = entry.pop("_spk")
        if not args.base_url:
            root = (args.adopt_root or args.apps).rstrip("/")
            adopt.append("%s\t%s\t%s" % (entry["packageId"], entry["sha256"], root + "/" + os.path.relpath(spk, args.apps)))
        if args.base_url:
            target = os.path.join(args.out, "packages", entry["packageId"] + ".spk")
            if not os.path.exists(target):
                try:
                    os.link(spk, target)
                except OSError:  # another filesystem
                    import shutil
                    shutil.copyfile(spk, target)
        sums.append("%s  %s.spk" % (entry["sha256"], entry["packageId"]))
        apps.append({k: entry[k] for k in LOCAL_FIELDS if k in entry})
    with open(os.path.join(args.out, "local.json"), "w") as f:
        json.dump({"apps": apps}, f, indent=1, sort_keys=True)
        f.write("\n")
    with open(os.path.join(args.out, "SHA256SUMS"), "w") as f:
        f.write("\n".join(sums) + "\n")
    if adopt:
        with open(os.path.join(args.out, "adopt.tsv"), "w") as f:
            f.write("\n".join(adopt) + "\n")
    print("fresh-index: %d packages -> %s/local.json" % (len(apps), args.out))


if __name__ == "__main__":
    main()
