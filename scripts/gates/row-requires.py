#!/usr/bin/env python3
"""Rows a candidate can judge (scripts/gates/row-requires.tsv).

  row-requires.py check ROW              exit 0: judge it; exit 10: print "requires <commit> (<why>)"
  row-requires.py filter TSV             TSV rows (ROW<TAB>VERDICT<TAB>...) whose product is not in the candidate
                                         are rewritten SKIPPED-NOT-IN-CANDIDATE, detail "requires <commit>: <why>"
  row-requires.py selftest

The candidate's commit is PRODUCT_COMMIT; objects come from ROW_REQUIRES_GIT (default: this script's repository).
With no PRODUCT_COMMIT every row is judged (a run against its own tree). An unknown commit is refused, never
guessed: a row is skipped only on a definite `git merge-base --is-ancestor` answer of no.
"""
import fnmatch, os, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKIP = "SKIPPED-NOT-IN-CANDIDATE"


def manifest(path=HERE / "row-requires.tsv"):
    out = []
    for n, line in enumerate(open(path), 1):
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        if len(cols) != 3 or not cols[0] or len(cols[1]) != 40:
            sys.exit(f"row-requires: {path}:{n}: want ROW-GLOB<TAB>40-hex COMMIT<TAB>WHY")
        out.append(tuple(cols))
    return out


def ancestor(git, required, product):
    rc = subprocess.run(["git", "-C", git, "merge-base", "--is-ancestor", required, product],
                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if rc.returncode in (0, 1):
        return rc.returncode == 0
    sys.exit(f"row-requires: cannot decide {required[:12]} against {product[:12]} in {git}: {rc.stderr.strip()}")


class Judge:
    def __init__(self, rows, product, git):
        self.rows, self.product, self.git, self.memo = rows, product, git, {}

    def missing(self, row):
        if not self.product:
            return None
        for glob, commit, why in self.rows:
            if fnmatch.fnmatchcase(row, glob):
                if commit not in self.memo:
                    self.memo[commit] = ancestor(self.git, commit, self.product)
                if not self.memo[commit]:
                    return f"requires {commit[:12]}: {why}"
        return None


def judge():
    git = os.environ.get("ROW_REQUIRES_GIT") or str(HERE.parent.parent)
    return Judge(manifest(), os.environ.get("PRODUCT_COMMIT", ""), git)


def filter_tsv(j, path):
    lines = []
    for line in open(path):
        c = line.rstrip("\n").split("\t")
        why = j.missing(c[0]) if len(c) >= 2 else None
        if why:
            c[1] = SKIP
            c[2:] = [why] if len(c) <= 3 else [why] + c[3:]
        lines.append("\t".join(c) + "\n")
    sys.stdout.write("".join(lines))


def selftest():
    with tempfile.TemporaryDirectory() as d:
        g = lambda *a: subprocess.run(["git", "-C", d, *a], check=True, capture_output=True, text=True).stdout.strip()
        g("init", "-q"); g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "a")
        a = g("rev-parse", "HEAD")
        g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "b")
        b = g("rev-parse", "HEAD")
        rows = [("new-*", b, "the feature"), ("OLD", a, "old feature")]
        old, new = Judge(rows, a, d), Judge(rows, b, d)
        assert old.missing("new-row") == f"requires {b[:12]}: the feature"
        assert old.missing("OLD") is None and old.missing("unlisted") is None
        assert new.missing("new-row") is None
        assert Judge(rows, "", d).missing("new-row") is None
        tsv = Path(d) / "t.tsv"; tsv.write_text("new-row\tFAIL\t404\nOLD\tPASS\t200\n")
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            filter_tsv(old, tsv)
        assert buf.getvalue() == f"new-row\t{SKIP}\trequires {b[:12]}: the feature\nOLD\tPASS\t200\n", buf.getvalue()
        try:
            Judge(rows, "f" * 40, d).missing("new-row"); raise AssertionError("an unknown commit must refuse")
        except SystemExit:
            pass
    manifest()
    print("row-requires selftest: ok")


if __name__ == "__main__":
    if sys.argv[1:2] == ["selftest"]:
        selftest()
    elif sys.argv[1:2] == ["check"] and len(sys.argv) == 3:
        why = judge().missing(sys.argv[2])
        if why:
            print(why); sys.exit(10)
    elif sys.argv[1:2] == ["filter"] and len(sys.argv) == 3:
        filter_tsv(judge(), sys.argv[2])
    else:
        sys.exit(__doc__)
