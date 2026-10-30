#!/usr/bin/env python3
"""Fabric-only source-binding and must-fail source-mutation checks.

Input archives are read as DATA, never extracted or executed. The binding is
source evidence, not a Rust refinement theorem; native differential receipts
remain an independent qualification obligation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Kernel/GenericSimplex.lean"
CONTROLS = "Verify/GenericSimplexJumpControls.lean"


def code(text):
    """Strip nested Lean comments, preserving code token boundaries."""
    out, index, depth = [], 0, 0
    while index < len(text):
        pair = text[index:index + 2]
        if pair == "/-":
            depth += 1
            index += 2
        elif depth and pair == "-/":
            depth -= 1
            index += 2
            out.append(" ")
        elif depth:
            index += 1
        elif pair == "--":
            end = text.find("\n", index)
            index = len(text) if end < 0 else end
            out.append(" ")
        else:
            out.append(text[index])
            index += 1
    if depth:
        raise ValueError("unterminated comment")
    return " ".join("".join(out).split())


def bind(args):
    archive = args.bundle
    if archive is None:
        archive = str(Path(os.environ["FAB_INPUT_DIR"]) / "c5-source-input.tar")
    with tarfile.open(archive, "r:") as bundle:
        if bundle.pax_headers.get("comment") != args.clockdag_tip:
            raise ValueError("git archive commit does not match declared C5 tip")
        oracle = bundle.extractfile("clockdag-simplex-oracle/Kernel/GenericSimplex.lean").read()
        native = bundle.extractfile("crates/mesh-simplex/src/lib.rs").read()
    if hashlib.sha256(native).hexdigest() != args.native_sha256:
        raise ValueError("native source digest mismatch")
    if hashlib.sha256(oracle).hexdigest() != args.oracle_sha256:
        raise ValueError("oracle source digest mismatch")
    mirror = code(oracle.decode())
    # C5's documented application policy chooses newest, minidregg oldest.
    # The proved entry frame allows either payload, but this is NOT whole-tree equality.
    newest = "s.offers.reverse.find?"
    if mirror.count(newest) != 1:
        raise ValueError("expected exactly the documented offer-policy difference")
    comparable = mirror.replace(newest, "s.offers.find?")
    local = code(SOURCE.read_text())
    if comparable != local:
        raise ValueError("kernel mismatch beyond documented newest/oldest offer policy")
    # Gate sensitivity: a source-level jump successor change must be noticed.
    changed = comparable.replace("preparedAbove s + 1", "preparedAbove s")
    if changed == comparable or changed == local:
        raise ValueError("source-binding mutation was not detected")
    print(json.dumps({"check": "c5-source-binding", "clockdag_tip": args.clockdag_tip,
                      "native_sha256": args.native_sha256, "oracle_sha256": args.oracle_sha256,
                      "local_kernel_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                      "qualified_difference": "propose newest vs oldest checked offer",
                      "successor_mutation_rejected": True}, sort_keys=True), flush=True)
    if args.kernel_check:
        if not os.environ.get("FAB_ID"):
            raise ValueError("kernel checks run only inside a Fabric job snapshot")
        original = SOURCE.read_bytes()
        try:
            SOURCE.write_bytes(oracle)
            checked = run(["lake", "build", "Kernel.GenericSimplexJumpSafety"])
            if checked.returncode:
                raise ValueError("general jump proof failed on exact C5 oracle source\n" + checked.stdout)
            print(json.dumps({"check": "general-proof-on-exact-c5-oracle", "lean_exit": 0,
                              "clockdag_tip": args.clockdag_tip}, sort_keys=True), flush=True)
        finally:
            SOURCE.write_bytes(original)
            restored = run(["lake", "build", "Kernel.GenericSimplexJumpSafety"])
            if restored.returncode:
                raise ValueError("restored general proof failed\n" + restored.stdout)


def run(argv):
    return subprocess.run(argv, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT)


def mutate(_args):
    if not os.environ.get("FAB_ID"):
        raise ValueError("source mutation checks run only inside a Fabric job snapshot")
    original = SOURCE.read_text()
    jump = "s := enterView c s (preparedAbove s + 1)"
    mutations = [
        ("max-to-min", "then max acc n else acc", "then min acc n else acc", "selection_control"),
        ("unprepared-hint", "s.current < n && !(viewAt s n).prepared.isEmpty", "s.current < n", "selection_control"),
        ("ordinary-only", jump, "s := s", "successor_control"),
        ("jump-to-j", jump, "s := enterView c s (preparedAbove s)", "successor_control"),
        ("wrong-deadline", "deadline := s.now + viewTimeout c s number", "deadline := s.now + c.timeout", "deadline_control"),
        ("fabricate-disabled", jump, jump + "\n    s := {s with views := s.views.map (fun v => {v with disabled := true})}", "flags_control"),
        ("erase-lock", jump, jump + "\n    s := {s with views := s.views.map (fun v => {v with sentCommit := none})}", "flags_control"),
        ("duplicate-votes", ")).map Message.sender).eraseDups.length", ")).map Message.sender).length", "quorum_control"),
        ("ready-below-2f1", "if count v .ready arg ≥ 2 * c.faults + 1 then", "if count v .ready arg ≥ 2 * c.faults then", "quorum_control"),
    ]
    try:
        for name, old, new, expected in mutations:
            if original.count(old) != 1:
                raise ValueError(f"{name}: mutation site is not unique")
            SOURCE.write_text(original.replace(old, new))
            built = run(["lake", "build", "Kernel.GenericSimplex"])
            if built.returncode:
                raise ValueError(f"{name}: mutated executable did not compile\n{built.stdout}")
            checked = run(["lake", "env", "lean", CONTROLS])
            # The pins name the failed theorem; unrelated compiler failures do not count.
            if checked.returncode == 0 or expected not in checked.stdout or "sorryAx" not in checked.stdout:
                raise ValueError(f"{name}: intended control did not reject mutant\n{checked.stdout}")
            print(json.dumps({"mutation": name, "executable_compiled": True,
                              "control": expected, "lean_exit": checked.returncode,
                              "rejected": True}, sort_keys=True), flush=True)
    finally:
        SOURCE.write_text(original)
        restored = run(["lake", "build", "Kernel.GenericSimplex"])
        if restored.returncode:
            raise ValueError("restored executable failed to compile\n" + restored.stdout)
    checked = run(["lake", "env", "lean", CONTROLS])
    if checked.returncode:
        raise ValueError("restored controls failed\n" + checked.stdout)
    print(json.dumps({"check": "restored-controls", "lean_exit": 0,
                      "mutations_rejected": len(mutations)}, sort_keys=True), flush=True)


def claims(_args):
    checked = run(["lake", "env", "lean", "scripts/report-simplex-qualification.lean"])
    if checked.returncode:
        raise ValueError("qualification emitter failed\n" + checked.stdout)
    required = {"preparedAbove_spec", "enterView_safety", "enterView_other", "enterView_clock",
                "progressOuter_entry", "prepared_entry_safe", "progressOuter_jump_safety",
                "reachable_step_safety", "jumpSchedule_admitted", "jumpBefore_reachable",
                "jumpInput_allowed", "jump_nonvacuous", "nf_sizes_outside_legacy"}
    seen = set()
    for line in checked.stdout.splitlines():
        if "QUALIFICATION_CLAIM " not in line:
            continue
        row = json.loads(line.split("QUALIFICATION_CLAIM ", 1)[1])
        if row["module"] != "Kernel.GenericSimplexJumpSafety":
            continue
        name = row["theorem"].rsplit(".", 1)[-1]
        if name not in required:
            continue
        if row["trust"] != "kernel-standard" or not row["statement"]:
            raise ValueError("nonstandard or empty theorem claim: " + name)
        seen.add(name)
        print("CHECKED_JUMP_CLAIM " + json.dumps(row, sort_keys=True), flush=True)
    if seen != required:
        raise ValueError("qualification emitter missed declarations: " + repr(required - seen))
    print(json.dumps({"check": "elaborated-jump-claims", "count": len(seen),
                      "trust": "kernel-standard"}, sort_keys=True), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(required=True)
    binding = sub.add_parser("bind")
    binding.add_argument("--bundle")
    binding.add_argument("--kernel-check", action="store_true")
    binding.add_argument("--clockdag-tip", required=True)
    binding.add_argument("--native-sha256", required=True)
    binding.add_argument("--oracle-sha256", required=True)
    binding.set_defaults(action=bind)
    mutation = sub.add_parser("mutate")
    mutation.set_defaults(action=mutate)
    emitted = sub.add_parser("claims")
    emitted.set_defaults(action=claims)
    args = parser.parse_args()
    for field in ("clockdag_tip", "native_sha256", "oracle_sha256"):
        if hasattr(args, field) and not re.fullmatch(r"[0-9a-f]{40}" if field == "clockdag_tip" else r"[0-9a-f]{64}", getattr(args, field)):
            parser.error(f"malformed {field}")
    args.action(args)


if __name__ == "__main__":
    main()
