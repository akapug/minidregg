#!/usr/bin/env python3
"""Exercise build-native-host.sh's seated Lean wrapper (the real heredoc text) without invoking Lean.

Seats are memory-weighted: a compiler takes the weight its module has in MINIDREGG_LEAN_SEAT_WEIGHTS
(module<TAB>weight), all of the seats when its module has no row, and refuses (64) when its weight
exceeds the seats. Checked here: 16 weight-1 compilers over 3 seats run 3 at once, balanced, seats
released, one RSS line each; five HEAVY compilers (weight = all seats) mixed with light ones never
overlap anything; weight-2 compilers never pair up on 3 seats; a heavy that queued behind running light
ones starts before light ones that queued after it (no starvation); an unrecorded module takes every
seat; an over-weight module refuses by name; occupied seats with MINIDREGG_LEAN_SEAT_WAIT=0 refuse with
75 and stay intact; a TERM delivered to the wrapper while its compiler runs does not release the seat
before the compiler exits.
"""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "scripts/build-native-host.sh").read_text()
WRAPPER = SOURCE.split('cat > "$wrapper_root/bin/lean" <<\'EOF\'\n', 1)[1].split("\nEOF\n", 1)[0] + "\n"
RUSAGE = SOURCE.split('cat > "$wrapper_root/lean-rusage.py" <<\'EOF\'\n', 1)[1].split("\nEOF\n", 1)[0] + "\n"


def events(log):
    """(kind, pid, value, t_index) per line; SEATS lines give the weight a pid held."""
    out = []
    for line in log.read_text().splitlines():
        f = line.split("\t")
        if f[0] == "SEATS":
            out.append(("SEATS", f[1], int(f[2]), f[3]))
        elif f[0] in ("START", "END"):
            out.append((f[0], f[2], None, None))
        elif f[0] == "RSS":
            out.append(("RSS", f[1], f[2], f[5]))
    return out


def replay(log):
    """Max concurrent compilers, max held weight, the set of (pid, module) that overlapped each heavy."""
    weight, module, active, held, m, mh, order = {}, {}, set(), 0, 0, 0, []
    overlaps = {}
    for kind, pid, value, mod in events(log):
        if kind == "SEATS":
            weight[pid], module[pid] = value, mod
        elif kind == "START":
            assert pid in weight and pid not in active, (pid, "START without SEATS or twice")
            for other in active:
                overlaps.setdefault(module[pid], set()).add(module[other])
                overlaps.setdefault(module[other], set()).add(module[pid])
            active.add(pid); held += weight[pid]; m = max(m, len(active)); mh = max(mh, held)
            order.append(module[pid])
        elif kind == "END":
            assert pid in active, pid
            active.remove(pid); held -= weight[pid]
    assert not active and held == 0, (active, held)
    return m, mh, overlaps, order


def clean(seats):
    assert not list(seats.glob("lean-seat-*")), list(seats.iterdir())
    assert not (seats / ".alloc-lock").exists()
    assert not list((seats / "waiters").iterdir()) if (seats / "waiters").exists() else True


with tempfile.TemporaryDirectory(prefix="mini-native-seats-") as temporary:
    root = Path(temporary)
    wrapper = root / "lean"
    wrapper.write_text(WRAPPER)
    (root / "lean-rusage.py").write_text(RUSAGE)
    fake = root / "fake-lean"
    fake.write_text("#!/bin/sh\nsleep 0.3\n")
    fake.chmod(0o755)
    slow_fake = root / "slow-fake-lean"
    slow_fake.write_text("#!/bin/sh\nsleep 1.2\n")
    slow_fake.chmod(0o755)
    seats = root / "seats"
    seats.mkdir()
    weights = root / "weights.tsv"
    rows = [f"M{i}\t1" for i in range(16)] + [f"H{i}\t3" for i in range(5)] + [f"L{i}\t1" for i in range(12)] \
        + [f"D{i}\t2" for i in range(4)] + ["Over\t4"]
    weights.write_text("\n".join(rows) + "\n")
    base = os.environ | {
        "MINIDREGG_REAL_LEAN": str(fake),
        "MINIDREGG_LEAN_SEAT_ROOT": str(seats),
        "MINIDREGG_LEAN_SEATS": "3",
        "MINIDREGG_LEAN_SEAT_WAIT": "120",
        "MINIDREGG_LEAN_BUILD_ROOT": str(root),
        "LEAN_NUM_THREADS": "2",
        "MINIDREGG_LEAN_RUSAGE": str(root / "lean-rusage.py"),
        "MINIDREGG_LEAN_SEAT_WEIGHTS": str(weights),
    }

    def run(names, log, stagger=0.0, env_extra=None):
        env = base | {"MINIDREGG_LEAN_WRAPPER_LOG": str(log)} | (env_extra or {})
        procs = []
        for name in names:
            procs.append(subprocess.Popen(["bash", str(wrapper), f"{name}.lean"], env=env))
            if stagger:
                time.sleep(stagger)
        assert all(p.wait(timeout=300) == 0 for p in procs)

    # 1. sixteen weight-1 compilers over 3 seats
    log = root / "w1.tsv"
    run([f"M{i}" for i in range(16)], log)
    m, mh, _, _ = replay(log)
    rss = [e[3] for e in events(log) if e[0] == "RSS"]
    assert m == 3 and mh == 3, (m, mh)
    assert len(rss) == 16 and all(rc == "0" for rc in rss), rss
    clean(seats)
    print("PASS: 16 weight-1 compilers over 3 seats, at most and at least 3 at once, balanced, seats released, one RSS line each")

    # 2. five heavies (weight 3 of 3) mixed with light ones: a heavy never overlaps anything
    log = root / "heavy.tsv"
    run([n for i in range(5) for n in (f"H{i}", f"L{i}", f"L{i + 5}")][:15], log, stagger=0.05)
    m, mh, overlaps, _ = replay(log)
    assert mh <= 3, mh
    bad = {h: overlaps.get(h) for h in (f"H{i}" for i in range(5)) if overlaps.get(h)}
    assert not bad, bad
    clean(seats)
    print(f"PASS: 5 heavy compilers (weight 3 of 3) among 10 light ones: no heavy overlapped any compiler; max held weight {mh}, max concurrent {m}")

    # 3. weight-2 compilers on 3 seats never pair up; a weight-1 may join one
    log = root / "w2.tsv"
    run(["D0", "D1", "L0", "D2", "L1", "D3"], log, stagger=0.05)
    m, mh, overlaps, _ = replay(log)
    pairs = {d: {o for o in overlaps.get(d, set()) if o.startswith("D")} for d in ("D0", "D1", "D2", "D3")}
    assert mh <= 3 and not any(pairs.values()), (mh, pairs)
    clean(seats)
    print(f"PASS: weight-2 compilers on 3 seats never ran together (max held weight {mh})")

    # 4. no starvation: a heavy queued behind 3 running light ones starts before light ones queued after it
    log = root / "fair.tsv"
    env = base | {"MINIDREGG_LEAN_WRAPPER_LOG": str(log), "MINIDREGG_REAL_LEAN": str(slow_fake)}
    first = [subprocess.Popen(["bash", str(wrapper), f"L{i}.lean"], env=env) for i in range(3)]
    time.sleep(0.5)
    heavy = subprocess.Popen(["bash", str(wrapper), "H0.lean"], env=env | {"MINIDREGG_REAL_LEAN": str(fake)})
    time.sleep(1.1)   # tickets carry 1-s mtimes: the later light ones queue strictly after the heavy
    later = [subprocess.Popen(["bash", str(wrapper), f"L{i}.lean"], env=env | {"MINIDREGG_REAL_LEAN": str(fake)}) for i in range(3, 9)]
    assert all(p.wait(timeout=300) == 0 for p in first + [heavy] + later)
    _, mh, overlaps, order = replay(log)
    assert order.index("H0") == 3 and not overlaps.get("H0"), order
    clean(seats)
    print(f"PASS: a heavy queued behind running light compilers started before the 6 queued after it (order {' '.join(order)})")

    # 5. an unrecorded module takes every seat; an over-weight module refuses by name
    log = root / "unrec.tsv"
    run(["Unrecorded"], log)
    assert [e for e in events(log) if e[0] == "SEATS"][0][2] == 3
    over = subprocess.run(["bash", str(wrapper), "Over.lean"], env=base | {"MINIDREGG_LEAN_WRAPPER_LOG": str(log)},
                          capture_output=True, text=True)
    assert over.returncode == 64 and "Over alone needs 4 of 3" in over.stderr, (over.returncode, over.stderr)
    clean(seats)
    print("PASS: an unrecorded module takes all 3 seats; a module whose weight exceeds the seats refuses 64 by name")

    # 6. occupied seats, no wait: refuse 75, owners untouched
    env = base | {"MINIDREGG_LEAN_WRAPPER_LOG": str(root / "occ.tsv")}
    for number in (1, 2, 3):
        seat = seats / f"lean-seat-{number}"
        seat.mkdir()
        (seat / "owner.txt").write_text("retained owner\n")
    refused = subprocess.run(["bash", str(wrapper), "M0.lean"], env=env | {"MINIDREGG_LEAN_SEAT_WAIT": "0"})
    assert refused.returncode == 75, refused.returncode
    assert all((seats / f"lean-seat-{n}/owner.txt").read_text() == "retained owner\n" for n in (1, 2, 3))
    for number in (1, 2, 3):
        (seats / f"lean-seat-{number}/owner.txt").unlink()
        (seats / f"lean-seat-{number}").rmdir()
    clean(seats)
    print("PASS: occupied seats refuse with 75 at MINIDREGG_LEAN_SEAT_WAIT=0 and stay intact")

    # 7. TERM to the wrapper: the seat outlives the compiler's own exit, never the other way round
    slow = root / "slow-lean"
    slow.write_text("#!/bin/sh\ntrap '' TERM\nsleep 1.5\n")
    slow.chmod(0o755)
    held = subprocess.Popen(["bash", str(wrapper), "M1.lean"], env=env | {"MINIDREGG_REAL_LEAN": str(slow)})
    deadline = time.monotonic() + 10
    while not (seats / "lean-seat-1").exists():
        assert time.monotonic() < deadline
        time.sleep(0.02)
    time.sleep(0.2)
    held.send_signal(signal.SIGTERM)
    time.sleep(0.5)
    assert (seats / "lean-seat-1").exists(), "seat released while the compiler still ran"
    held.wait(timeout=10)
    clean(seats)
    print("PASS: a TERMed wrapper holds its seat until the compiler exits, then releases it")
